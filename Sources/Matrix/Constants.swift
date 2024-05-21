//
//  Constants.swift
//  
//
//  Created by Charles Wright on 2/22/23.
//

import Foundation

public let DEFAULT_ROOM_VERSION = "11"

// MARK: Authentication types
public let M_LOGIN_PASSWORD = "m.login.password"

// MARK: Event Types
public let M_ROOM_CANONICAL_ALIAS = "m.room.canonical_alias"
public let M_ROOM_CREATE = "m.room.create"
public let M_ROOM_JOIN_RULES = "m.room.join_rules"
public let M_ROOM_MEMBER = "m.room.member"
public let M_ROOM_POWER_LEVELS = "m.room.power_levels"
public let M_ROOM_MESSAGE = "m.room.message"
public let M_REACTION = "m.reaction"
public let M_ROOM_REDACTION = "m.room.redaction"
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

// MARK: E2EE Event Types
public let M_ROOM_KEY = "m.room_key"
public let M_ROOM_KEY_REQUEST = "m.room_key_request"
public let M_FORWARDED_ROOM_KEY = "m.forwarded_room_key"
public let M_ROOM_KEY_WITHHELD = "m.room_key.withheld"

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
public let M_POLL_START = "m.poll.start"
public let M_POLL_RESPONSE = "m.poll.response"
public let M_POLL_END = "m.poll.end"
public let ORG_MATRIX_MSC1767_TEXT = "org.matrix.msc1767.text"

// MARK: Account Data Types

public let M_IDENTITY_SERVER = "m.identity_server"
public let M_FULLY_READ = "m.fully_read"
public let M_DIRECT = "m.direct"
public let M_IGNORED_USER_LIST = "m.ignored_user_list"
public let M_PUSH_RULES = "m.push_rules"
public let M_SECRET_STORAGE_KEY_PREFIX = "m.secret_storage.key" // Ugh this one is ugly.  The actual format is "m.secret_storage.key.[key ID]"
public let M_SECRET_STORAGE_DEFAULT_KEY = "m.secret_storage.default_key"
public let ORG_FUTO_SSSS_KEY_PREFIX = "org.futo.ssss.key" // This one is like M_SECRET_STORAGE_KEY_PREFIX but we use it to store encrypted keys as secrets, whereas the other one is only for storing the key descriptions
// We already have M_TAG = "m.tag"
public let M_MEGOLM_BACKUP_V1 = "m.megolm_backup.v1" // For storing the private half of the recovery key, as an encrypted secret

// MARK: Room types
public let M_SPACE = "m.space"

// MARK: Relationship types
public let M_ANNOTATION = "m.annotation"
public let M_THREAD = "m.thread"
public let M_REPLACE = "m.replace"
public let M_REFERENCE = "m.reference"

// MARK: Secret storage
public let M_SECRET_STORAGE_V1_AES_HMAC_SHA2 = "m.secret_storage.v1.aes-hmac-sha2"
public let M_PBKDF2 = "m.pbkdf2"
public let M_DEFAULT = "m.default"
public let M_CROSS_SIGNING_MASTER = "m.cross_signing.master"
public let M_CROSS_SIGNING_USER_SIGNING = "m.cross_signing.user_signing"
public let M_CROSS_SIGNING_SELF_SIGNING = "m.cross_signing.self_signing"

// MARK: Secret sharing
public let M_SECRET_REQUEST = "m.secret.request"
public let M_SECRET_SEND = "m.secret.send"

// MARK: Key backup
public let M_MEGOLM_BACKUP_V1_CURVE25519_AES_SHA2 = "m.megolm_backup.v1.curve25519-aes-sha2"

// MARK: Read receipts
public let M_READ = "m.read"
public let M_READ_PRIVATE = "m.read.private"
// m.fully_read is already defined above

// MARK: Poll types
public let ORG_MATRIX_MSC3381_POLL_START = "org.matrix.msc3381.poll.start"
public let ORG_MATRIX_MSC3381_POLL_RESPONSE = "org.matrix.msc3381.poll.response"
public let ORG_MATRIX_MSC3381_POLL_RESPONSE_ALIAS = "org.matrix.msc3381.poll"
public let ORG_MATRIX_MSC3381_POLL_END = "org.matrix.msc3381.poll.end"

// MARK: Matrix errors
// https://spec.matrix.org/v1.8/client-server-api/#common-error-codes
public let M_UNKNOWN_TOKEN = "M_UNKNOWN_TOKEN"
public let M_FORBIDDEN = "M_FORBIDDEN"
public let M_MISSING_TOKEN = "M_MISSING_TOKEN"
public let M_BAD_JSON = "M_BAD_JSON"
public let M_NOT_FOUND = "M_NOT_FOUND"
public let M_LIMIT_EXCEEDED = "M_LIMIT_EXCEEDED"
public let M_UNRECOGNIZED = "M_UNRECOGNIZED"
public let M_UNKNOWN = "M_UNKNOWN"

// https://spec.matrix.org/v1.8/client-server-api/#other-error-codes
public let M_UNAUTHORIZED = "M_UNAUTHORIZED"
public let M_USER_DEACTIVATED = "M_USER_DEACTIVATED"
public let M_USER_IN_USE = "M_USER_IN_USE"
public let M_INVALID_USERNAME = "M_INVALID_USERNAME"
public let M_ROOM_IN_USE = "M_ROOM_IN_USE"
public let M_INVALID_ROOM_STATE = "M_INVALID_ROOM_STATE"
public let M_THREEPID_IN_USE = "M_THREEPID_IN_USE"
public let M_THREEPID_NOT_FOUND = "M_THREEPID_NOT_FOUND"
public let M_THREEPID_AUTH_FAILED = "M_THREEPID_AUTH_FAILED"
public let M_THREEPID_DENIED = "M_THREEPID_AUTH_FAILED"
public let M_SERVER_NOT_TRUSTED = "M_SERVER_NOT_TRUSTED"
public let M_UNSUPPORTED_ROOM_VERSION = "M_UNSUPPORTED_ROOM_VERSION"
public let M_INCOMPATIBLE_ROOM_VERSION = "M_INCOMPATIBLE_ROOM_VERSION"
public let M_BAD_STATE = "M_BAD_STATE"
public let M_GUEST_ACCESS_FORBIDDEN = "M_GUEST_ACCESS_FORBIDDEN"
public let M_CAPTCHA_NEEDED = "M_CAPTCHA_NEEDED"
public let M_CAPTCHA_INVALID = "M_CAPTCHA_INVALID"
public let M_MISSING_PARAM = "M_MISSING_PARAM"
public let M_INVALID_PARAM = "M_INVALID_PARAM"
public let M_TOO_LARGE = "M_TOO_LARGE"
public let M_EXCLUSIVE = "M_EXCLUSIVE"
public let M_RESOURCE_LIMIT_EXCEEDED = "M_RESOURCE_LIMIT_EXCEEDED"
public let M_CANNOT_LEAVE_SERVER_NOTICE_ROOM = "M_CANNOT_LEAVE_SERVER_NOTICE_ROOM"

// MARK: FUTO types
// Keys are already prefixed with ORG_FUTO_SSSS_KEY_PREFIX
public let ORG_FUTO_SSSS_KEY_DEHYDRATION = "dehydrated_device"
