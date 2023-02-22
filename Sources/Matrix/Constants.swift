//
//  Constants.swift
//  
//
//  Created by Charles Wright on 2/22/23.
//

import Foundation

// MARK: Event Types
let M_ROOM_CANONICAL_ALIAS = "m.room.canonical_alias"
let M_ROOM_CREATE = "m.room.create"
let M_ROOM_JOIN_RULES = "m.room.join_rules"
let M_ROOM_MEMBER = "m.room.member"
let M_ROOM_POWER_LEVELS = "m.room.power_levels"
let M_ROOM_MESSAGE = "m.room.message"
let M_REACTION = "m.reaction"
let M_ROOM_ENCRYPTION = "m.room.encryption"
let M_ENCRYPTED = "m.encrypted"
let M_ROOM_TOMBSTONE = "m.room.tombstone"

let M_ROOM_NAME = "m.room.name"
let M_ROOM_AVATAR = "m.room.avatar"
let M_ROOM_TOPIC = "m.room.topic"

let M_PRESENCE = "m.presence"
let M_TYPING = "m.typing"
let M_RECEIPT = "m.receipt"
let M_ROOM_HISTORY_VISIBILITY = "m.room.history_visibility"
let M_ROOM_GUEST_ACCESS = "m.room.guest_access"
let M_TAG = "m.tag"
// case mRoomPinnedEvents = "m.room.pinned_events" // https://spec.matrix.org/v1.2/client-server-api/#mroompinned_events

let M_SPACE_CHILD = "m.space.child"
let M_SPACE_PARENT = "m.space.parent"

// Add types for extensible events here

// MARK: Message Types

let M_TEXT = "m.text"
let M_EMOTE = "m.emote"
let M_NOTICE = "m.notice"
let M_IMAGE = "m.image"
let M_FILE = "m.file"
let M_AUDIO = "m.audio"
let M_VIDEO = "m.video"
let M_LOCATION = "m.location"

// MARK: Account Data Types

let M_IDENTITY_SERVER = "m.identity_server"
let M_FULLY_READ = "m.fully_read"
let M_DIRECT = "m.direct"
let M_IGNORED_USER_LIST = "m.ignored_user_list"
let M_PUSH_RULES = "m.push_rules"
let M_SECRET_STORAGE_KEY = "m.secret_storage_key" // Ugh this one is FUBAR.  The actual format is "m.secret_storage.key.[key ID]"
// We already have M_TAG = "m.tag"
