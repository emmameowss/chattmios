import Foundation

/// Catalog of slash commands supported by the chattm server. Commands are sent
/// as ordinary `message` text; the server parses any text starting with `/`.
struct SlashCommand: Identifiable, Equatable {
    let name: String        // including leading slash, e.g. "/nick"
    let args: String        // human hint, e.g. "[name]"
    let summary: String
    let ownerOnly: Bool

    var id: String { name }
    var display: String { args.isEmpty ? name : "\(name) \(args)" }

    static let all: [SlashCommand] = [
        // User commands
        .init(name: "/nick", args: "[name]", summary: "Change your username", ownerOnly: false),
        .init(name: "/color", args: "[hex|flag]", summary: "Set your name color", ownerOnly: false),
        .init(name: "/colour", args: "[hex|flag]", summary: "Set your name color", ownerOnly: false),
        .init(name: "/whois", args: "[username]", summary: "Reveal a user's email", ownerOnly: true),
        // Owner — moderation
        .init(name: "/ban", args: "[username] [reason]", summary: "Ban user + IP", ownerOnly: true),
        .init(name: "/unban", args: "[email]", summary: "Remove a ban", ownerOnly: true),
        .init(name: "/unbanip", args: "[ip]", summary: "Unblock an IP", ownerOnly: true),
        .init(name: "/kick", args: "[username] [reason]", summary: "Disconnect a user", ownerOnly: true),
        .init(name: "/mute", args: "[username] [time] [reason]", summary: "Silence a user", ownerOnly: true),
        .init(name: "/unmute", args: "[username]", summary: "Restore a user's voice", ownerOnly: true),
        .init(name: "/resetstrikes", args: "[username]", summary: "Clear filter strikes", ownerOnly: true),
        // Owner — chat control
        .init(name: "/mutechat", args: "", summary: "Mute all chat", ownerOnly: true),
        .init(name: "/unmutechat", args: "", summary: "Unmute all chat", ownerOnly: true),
        .init(name: "/clear", args: "", summary: "Delete all messages", ownerOnly: true),
        .init(name: "/announce", args: "[text]", summary: "Broadcast an announcement", ownerOnly: true),
        .init(name: "/status", args: "[text]", summary: "Broadcast a status notice", ownerOnly: true),
        .init(name: "/maintenance", args: "[reason]", summary: "Enter maintenance mode", ownerOnly: true),
        .init(name: "/noguests", args: "", summary: "Disable guest access", ownerOnly: true),
        .init(name: "/allowguests", args: "", summary: "Enable guest access", ownerOnly: true),
        // Owner — customization & moderation
        .init(name: "/setcolor", args: "[username] [color]", summary: "Set a user's color", ownerOnly: true),
        .init(name: "/setnick", args: "[oldname] [newname]", summary: "Rename a user", ownerOnly: true),
        .init(name: "/verify", args: "[email]", summary: "Verify an account", ownerOnly: true),
        .init(name: "/unverify", args: "[email]", summary: "Revoke verification", ownerOnly: true),
        .init(name: "/redverify", args: "[email]", summary: "Grant red verification", ownerOnly: true),
        .init(name: "/unredverify", args: "[email]", summary: "Revoke red verification", ownerOnly: true),
        .init(name: "/addfilter", args: "[word]", summary: "Add a filtered word", ownerOnly: true),
        .init(name: "/removefilter", args: "[word]", summary: "Remove a filtered word", ownerOnly: true),
        .init(name: "/reloadfilter", args: "", summary: "Reload the word filter", ownerOnly: true),
        .init(name: "/addemoji", args: "[:code:] [url]", summary: "Add a custom emoji", ownerOnly: true),
        .init(name: "/removeemoji", args: "[:code:]", summary: "Remove a custom emoji", ownerOnly: true),
        .init(name: "/reloademojis", args: "", summary: "Reload emoji from storage", ownerOnly: true),
    ]

    /// Commands available to the given user, filtered for an autocomplete prefix.
    static func matching(prefix: String, isOwner: Bool) -> [SlashCommand] {
        let lower = prefix.lowercased()
        return all.filter { cmd in
            (isOwner || !cmd.ownerOnly) && cmd.name.hasPrefix(lower)
        }
    }
}
