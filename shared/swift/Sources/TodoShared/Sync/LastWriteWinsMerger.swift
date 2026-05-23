import Foundation

public enum LastWriteWinsMerger {
    public static func merge(local: TodoTask?, remote: TodoTask?) -> TodoTask? {
        switch (local, remote) {
        case (.none, .none):
            return nil
        case (.some(let task), .none), (.none, .some(let task)):
            return task
        case (.some(let localTask), .some(let remoteTask)):
            return winner(local: localTask, remote: remoteTask)
        }
    }

    public static func winner(local: TodoTask, remote: TodoTask) -> TodoTask {
        if local.updatedAt != remote.updatedAt {
            return local.updatedAt > remote.updatedAt ? local : remote
        }
        if local.version != remote.version {
            return local.version > remote.version ? local : remote
        }
        return remote
    }
}
