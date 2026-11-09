//! The state of one open folder dialog. Contains no SDL types: the backend's callback hands the
//! file list to `completeFromFileList`, on whichever thread SDL calls it, and the application
//! polls from its own loop.

const std = @import("std");

pub const FolderPickerError = error{
    /// The operating system could not show the dialog.
    FolderPickerFailed,
    OutOfMemory,
};

pub const FolderPickerOutcome = union(enum) {
    /// The chosen directory, owned by the allocator given to `poll`.
    selected: []u8,
    canceled,
};

pub const FolderPickerRequest = struct {
    allocator: std.mem.Allocator,
    /// Written once by the callback with release order after `selected_path` is set.
    completion: std.atomic.Value(Completion) = .init(.pending),
    selected_path: ?[]u8 = null,
    /// SDL reads this while the dialog is open, so the request owns it until the outcome.
    default_location: ?[:0]u8 = null,

    const Completion = enum(u8) { pending, selected, canceled, failed };

    /// Called by `requestFolderPicker`. Applications do not need it.
    pub fn create(allocator: std.mem.Allocator, default_location: ?[]const u8) std.mem.Allocator.Error!*FolderPickerRequest {
        const self = try allocator.create(FolderPickerRequest);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator };
        if (default_location) |location| self.default_location = try allocator.dupeSentinel(u8, location, 0);
        return self;
    }

    /// Records SDL's result. Called once, by the backend's callback. `file_list` is null on
    /// failure, holds a null first entry on cancel, and otherwise starts with the chosen path.
    pub fn completeFromFileList(self: *FolderPickerRequest, file_list: ?[*]const ?[*:0]const u8) void {
        const completion: Completion = completion: {
            const chosen_paths = file_list orelse break :completion .failed;
            const chosen_path = chosen_paths[0] orelse break :completion .canceled;
            self.selected_path = self.allocator.dupe(u8, std.mem.span(chosen_path)) catch break :completion .failed;
            break :completion .selected;
        };
        self.completion.store(completion, .release);
    }

    /// Null while the dialog is open. Otherwise returns the outcome or the failure and destroys
    /// the request, so `self` must not be used after a non-null result or an error. Poll until
    /// then: SDL still holds a pointer to the request while the dialog is open.
    pub fn poll(self: *FolderPickerRequest, allocator: std.mem.Allocator) FolderPickerError!?FolderPickerOutcome {
        switch (self.completion.load(.acquire)) {
            .pending => return null,
            .canceled => {
                self.destroy();
                return FolderPickerOutcome.canceled;
            },
            .failed => {
                self.destroy();
                return error.FolderPickerFailed;
            },
            .selected => {
                defer self.destroy();
                return .{ .selected = try allocator.dupe(u8, self.selected_path.?) };
            },
        }
    }

    fn destroy(self: *FolderPickerRequest) void {
        if (self.selected_path) |path| self.allocator.free(path);
        if (self.default_location) |location| self.allocator.free(location);
        self.allocator.destroy(self);
    }
};
