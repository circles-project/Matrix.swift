//
//  Constants.swift
//  
//
//  Created by Charles Wright on 2/22/23.
//

import Foundation

// MARK: Event Types
public let M_ROOM_CANONICAL_ALIAS = "m.room.canonical_alias"
public let M_ROOM_CREATE = "m.room.create"
public let M_ROOM_JOIN_RULES = "m.room.join_rules"
public let M_ROOM_MEMBER = "m.room.member"
public let M_ROOM_POWER_LEVELS = "m.room.power_levels"
public let M_ROOM_MESSAGE = "m.room.message"
public let M_REACTION = "m.reaction"
public let M_ROOM_ENCRYPTION = "m.room.encryption"
public let M_ROOM_ENCRYPTED = "m.room.encrypted"
public let M_ROOM_TOMBSTONE = "m.room.tombstone"

public let M_ROOM_NAME = "m.room.name"
public let M_ROOM_AVATAR = "m.room.avatar"
public let M_ROOM_TOPIC = "m.room.topic"

public let M_PRESENCE = "m.presence"
public let M_TYPING = "m.typing"
public let M_RECEIPT = "m.receipt"
public let M_ROOM_HISTORY_VISIBILITY = "m.room.history_visibility"
public let M_ROOM_GUEST_ACCESS = "m.room.guest_access"
public let M_TAG = "m.tag"
// case mRoomPinnedEvents = "m.room.pinned_events" // https://spec.matrix.org/v1.2/client-server-api/#mroompinned_events

public let M_SPACE_CHILD = "m.space.child"
public let M_SPACE_PARENT = "m.space.parent"

// Add types for extensible events here

// MARK: Message Types

public let M_TEXT = "m.text"
public let M_EMOTE = "m.emote"
public let M_NOTICE = "m.notice"
public let M_IMAGE = "m.image"
public let M_FILE = "m.file"
public let M_AUDIO = "m.audio"
public let M_VIDEO = "m.video"
public let M_LOCATION = "m.location"

// MARK: Account Data Types

public let M_IDENTITY_SERVER = "m.identity_server"
public let M_FULLY_READ = "m.fully_read"
public let M_DIRECT = "m.direct"
public let M_IGNORED_USER_LIST = "m.ignored_user_list"
public let M_PUSH_RULES = "m.push_rules"
public let M_SECRET_STORAGE_KEY = "m.secret_storage_key" // Ugh this one is FUBAR.  The actual format is "m.secret_storage.key.[key ID]"
// We already have M_TAG = "m.tag"
