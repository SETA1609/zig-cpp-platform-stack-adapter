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
        _ = allocator;
        _ = default_location;
        @panic("not implemented");
    }

    /// Records SDL's result. Called once, by the backend's callback. `file_list` is null on
    /// failure, holds a null first entry on cancel, and otherwise starts with the chosen path.
    pub fn completeFromFileList(self: *FolderPickerRequest, file_list: ?[*]const ?[*:0]const u8) void {
        _ = self;
        _ = file_list;
        @panic("not implemented");
    }

    /// Null while the dialog is open. Otherwise returns the outcome or the failure and destroys
    /// the request, so `self` must not be used after a non-null result or an error. Poll until
    /// then: SDL still holds a pointer to the request while the dialog is open.
    pub fn poll(self: *FolderPickerRequest, allocator: std.mem.Allocator) FolderPickerError!?FolderPickerOutcome {
        _ = self;
        _ = allocator;
        @panic("not implemented");
    }
};
