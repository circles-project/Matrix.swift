// Sample responses taken from matrix spec: https://spec.matrix.org/v1.5/client-server-api/
struct JSONResponses {
    // MARK: Capabilities
    struct Capabilities {
        static let capabilities = """
            {
              "capabilities": {
                "com.example.custom.ratelimit": {
                  "max_requests_per_hour": 600
                },
                "m.change_password": {
                  "enabled": false
                },
                "m.room_versions": {
                  "available": {
                    "1": "stable",
                    "2": "stable",
                    "3": "unstable",
                    "test-version": "unstable"
                  },
                  "default": "1"
                }
              }
            }
            """.data(using: .utf8)!
        
        static let changePassword = """
            {
              "capabilities": {
                "m.change_password": {
                  "enabled": false
                }
              }
            }
            """.data(using: .utf8)!
        
        static let roomVersions = """
            {
              "capabilities": {
                "m.room_versions": {
                  "default": "1",
                  "available": {
                    "1": "stable",
                    "2": "stable",
                    "3": "unstable",
                    "custom-version": "unstable"
                  }
                }
              }
            }
            """.data(using: .utf8)!
        
        static let displayname = """
            {
              "capabilities": {
                "m.set_displayname": {
                  "enabled": false
                }
              }
            }
            """.data(using: .utf8)!
        
        static let avatarUrl = """
            {
              "capabilities": {
                "m.set_avatar_url": {
                  "enabled": false
                }
              }
            }
            """.data(using: .utf8)!
        
        static let pid = """
            {
              "capabilities": {
                "m.3pid_changes": {
                  "enabled": false
                }
              }
            }
            """.data(using: .utf8)!
    }
    
    
    struct RoomEvent {
        // MARK: Call Events
        struct Call {
            static let answer = """
                {
                  "content": {
                    "answer": {
                      "sdp": "v=0\r\no=- 6584580628695956864 2 IN IP4 127.0.0.1[...]",
                      "type": "answer"
                    },
                    "call_id": "12345",
                    "version": 0
                  },
                  "event_id": "$143273582443PhrSn:example.org",
                  "origin_server_ts": 1432735824653,
                  "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
                  "sender": "@example:example.org",
                  "type": "m.call.answer",
                  "unsigned": {
                    "age": 1234
                  }
                }
                """.data(using: .utf8)!
            
            static let candidates = """
                {
                  "content": {
                    "call_id": "12345",
                    "candidates": [
                      {
                        "candidate": "candidate:863018703 1 udp 2122260223 10.9.64.156 43670 typ host generation 0",
                        "sdpMLineIndex": 0,
                        "sdpMid": "audio"
                      }
                    ],
                    "version": 0
                  },
                  "event_id": "$143273582443PhrSn:example.org",
                  "origin_server_ts": 1432735824653,
                  "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
                  "sender": "@example:example.org",
                  "type": "m.call.candidates",
                  "unsigned": {
                    "age": 1234
                  }
                }
                """.data(using: .utf8)!
            
            static let hangup = """
                {
                  "content": {
                    "call_id": "12345",
                    "version": 0
                  },
                  "event_id": "$143273582443PhrSn:example.org",
                  "origin_server_ts": 1432735824653,
                  "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
                  "sender": "@example:example.org",
                  "type": "m.call.hangup",
                  "unsigned": {
                    "age": 1234
                  }
                }
                """.data(using: .utf8)!
            
            static let invite = """
                {
                  "content": {
                    "call_id": "12345",
                    "lifetime": 60000,
                    "offer": {
                      "sdp": "v=0\r\no=- 6584580628695956864 2 IN IP4 127.0.0.1[...]",
                      "type": "offer"
                    },
                    "version": 0
                  },
                  "event_id": "$143273582443PhrSn:example.org",
                  "origin_server_ts": 1432735824653,
                  "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
                  "sender": "@example:example.org",
                  "type": "m.call.invite",
                  "unsigned": {
                    "age": 1234
                  }
                }
                """.data(using: .utf8)!
        }
        
        // MARK: Key Events
        struct Key {
            static let requestMessage = """
                {
                  "content": {
                    "body": "Alice is requesting to verify your device, but your client does not support verification, so you may need to use a different verification method.",
                    "from_device": "AliceDevice2",
                    "methods": [
                      "m.sas.v1"
                    ],
                    "msgtype": "m.key.verification.request",
                    "to": "@bob:example.org"
                  },
                  "event_id": "$143273582443PhrSn:example.org",
                  "origin_server_ts": 1432735824653,
                  "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
                  "sender": "@alice:example.org",
                  "type": "m.room.message",
                  "unsigned": {
                    "age": 1234
                  }
                }
                """.data(using: .utf8)!
            
            static let request = """
                {
                  "content": {
                    "from_device": "AliceDevice2",
                    "methods": [
                      "m.sas.v1"
                    ],
                    "timestamp": 1559598944869,
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.request"
                }
                """.data(using: .utf8)!
            
            static let ready = """
                {
                  "content": {
                    "from_device": "BobDevice1",
                    "methods": [
                      "m.sas.v1"
                    ],
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.ready"
                }
                """.data(using: .utf8)!
            
            static let start1 = """
                {
                  "content": {
                    "from_device": "BobDevice1",
                    "method": "m.sas.v1",
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.start"
                }
                """.data(using: .utf8)!
            
            static let start2 = """
                {
                  "content": {
                    "from_device": "BobDevice1",
                    "hashes": [
                      "sha256"
                    ],
                    "key_agreement_protocols": [
                      "curve25519"
                    ],
                    "message_authentication_codes": [
                      "hkdf-hmac-sha256"
                    ],
                    "method": "m.sas.v1",
                    "short_authentication_string": [
                      "decimal",
                      "emoji"
                    ],
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.start"
                }
                """.data(using: .utf8)!
            
            static let done = """
                {
                  "content": {
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.done"
                }
                """.data(using: .utf8)!
            
            static let cancel = """
                {
                  "content": {
                    "code": "m.user",
                    "reason": "User rejected the key verification request",
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.cancel"
                }
                """.data(using: .utf8)!
            
            static let accept = """
                {
                  "content": {
                    "commitment": "fQpGIW1Snz+pwLZu6sTy2aHy/DYWWTspTJRPyNp0PKkymfIsNffysMl6ObMMFdIJhk6g6pwlIqZ54rxo8SLmAg",
                    "hash": "sha256",
                    "key_agreement_protocol": "curve25519",
                    "message_authentication_code": "hkdf-hmac-sha256",
                    "method": "m.sas.v1",
                    "short_authentication_string": [
                      "decimal",
                      "emoji"
                    ],
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.accept"
                }
                """.data(using: .utf8)!
            
            static let key = """
                {
                  "content": {
                    "key": "fQpGIW1Snz+pwLZu6sTy2aHy/DYWWTspTJRPyNp0PKkymfIsNffysMl6ObMMFdIJhk6g6pwlIqZ54rxo8SLmAg",
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.key"
                }
                """.data(using: .utf8)!
            
            static let mac = """
                {
                  "content": {
                    "keys": "2Wptgo4CwmLo/Y8B8qinxApKaCkBG2fjTWB7AbP5Uy+aIbygsSdLOFzvdDjww8zUVKCmI02eP9xtyJxc/cLiBA",
                    "mac": {
                      "ed25519:ABCDEF": "fQpGIW1Snz+pwLZu6sTy2aHy/DYWWTspTJRPyNp0PKkymfIsNffysMl6ObMMFdIJhk6g6pwlIqZ54rxo8SLmAg"
                    },
                    "transaction_id": "S0meUniqueAndOpaqueString"
                  },
                  "type": "m.key.verification.mac"
                }
                """.data(using: .utf8)!
        }
        
        // MARK: Room Events
        static let clientEvent = """
            {
              "content": {
                "membership": "join"
              },
              "event_id": "$26RqwJMLw-yds1GAH_QxjHRC1Da9oasK0e5VLnck_45",
              "origin_server_ts": 1632489532305,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "@user:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1567437,
                "redacted_because": {
                  "content": {
                    "reason": "spam"
                  },
                  "event_id": "$Nhl3rsgHMjk-DjMJANawr9HHAhLg4GcoTYrSiYYGqEE",
                  "origin_server_ts": 1632491098485,
                  "redacts": "$26RqwJMLw-yds1GAH_QxjHRC1Da9oasK0e5VLnck_45",
                  "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
                  "sender": "@moderator:example.org",
                  "type": "m.room.redaction",
                  "unsigned": {
                    "age": 1257
                  }
                }
              }
            }
            """.data(using: .utf8)!
        
        static let canonicalAlias = """
            {
              "content": {
                "alias": "#somewhere:localhost",
                "alt_aliases": [
                  "#somewhere:example.org",
                  "#myroom:example.com"
                ]
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.canonical_alias",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let roomCreate = """
            {
              "content": {
                "creator": "@example:example.org",
                "m.federate": true,
                "predecessor": {
                  "event_id": "$something:example.org",
                  "room_id": "!oldroom:example.org"
                },
                "room_version": "1"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.create",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let joinRules1 = """
            {
              "content": {
                "join_rule": "public"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.join_rules",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let joinRules2 = """
            {
              "content": {
                "allow": [
                  {
                    "room_id": "!other:example.org",
                    "type": "m.room_membership"
                  },
                  {
                    "room_id": "!elsewhere:example.org",
                    "type": "m.room_membership"
                  }
                ],
                "join_rule": "restricted"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.join_rules",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let member1 = """
            {
              "content": {
                "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                "displayname": "Alice Margatroid",
                "membership": "join",
                "reason": "Looking for support"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "@alice:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let member2 = """
            {
              "content": {
                "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                "displayname": "Alice Margatroid",
                "membership": "invite",
                "reason": "Looking for support"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "@alice:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1234,
                "invite_room_state": [
                  {
                    "content": {
                      "name": "Example Room"
                    },
                    "sender": "@bob:example.org",
                    "state_key": "",
                    "type": "m.room.name"
                  },
                  {
                    "content": {
                      "join_rule": "invite"
                    },
                    "sender": "@bob:example.org",
                    "state_key": "",
                    "type": "m.room.join_rules"
                  }
                ]
              }
            }
            """.data(using: .utf8)!
        
        static let member3 = """
            {
              "content": {
                "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                "displayname": "Alice Margatroid",
                "join_authorised_via_users_server": "@bob:other.example.org",
                "membership": "join"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "@alice:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let member4 = """
            {
              "content": {
                "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                "displayname": "Alice Margatroid",
                "membership": "knock",
                "reason": "Looking for support"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "@alice:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1234,
                "knock_room_state": [
                  {
                    "content": {
                      "name": "Example Room"
                    },
                    "sender": "@bob:example.org",
                    "state_key": "",
                    "type": "m.room.name"
                  },
                  {
                    "content": {
                      "join_rule": "knock"
                    },
                    "sender": "@bob:example.org",
                    "state_key": "",
                    "type": "m.room.join_rules"
                  }
                ]
              }
            }
            """.data(using: .utf8)!
        
        static let member5 = """
            {
              "content": {
                "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                "displayname": "Alice Margatroid",
                "membership": "invite",
                "third_party_invite": {
                  "display_name": "alice",
                  "signed": {
                    "mxid": "@alice:example.org",
                    "signatures": {
                      "magic.forest": {
                        "ed25519:3": "fQpGIW1Snz+pwLZu6sTy2aHy/DYWWTspTJRPyNp0PKkymfIsNffysMl6ObMMFdIJhk6g6pwlIqZ54rxo8SLmAg"
                      }
                    },
                    "token": "abc123"
                  }
                }
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "@alice:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let powerLevels = """
            {
              "content": {
                "ban": 50,
                "events": {
                  "m.room.name": 100,
                  "m.room.power_levels": 100
                },
                "events_default": 0,
                "invite": 50,
                "kick": 50,
                "notifications": {
                  "room": 20
                },
                "redact": 50,
                "state_default": 50,
                "users": {
                  "@example:localhost": 100
                },
                "users_default": 0
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.power_levels",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let message = """
            {
              "content": {
                "body": "This is an example text message",
                "format": "org.matrix.custom.html",
                "formatted_body": "<b>This is an example text message</b>",
                "msgtype": "m.text"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:matrix.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let redaction = """
            {
              "content": {
                "reason": "Spamming"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "redacts": "$fukweghifu23:localhost",
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.redaction",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let relatesTo = """
            {
              "m.relates_to": {
                "event_id": "$an_event",
                "rel_type": "org.example.relationship"
              }
            }
            """.data(using: .utf8)!
        
        static let name = """
            {
              "content": {
                "name": "The room name"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.name",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let topic = """
            {
              "content": {
                "topic": "A room topic"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.topic",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let avatar = """
            {
              "content": {
                "info": {
                  "h": 398,
                  "mimetype": "image/jpeg",
                  "size": 31037,
                  "w": 394
                },
                "url": "mxc://example.org/JWEIFJgwEIhweiWJE"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.avatar",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let pinnedEvents = """
            {
              "content": {
                "pinned": [
                  "$someevent:example.org"
                ]
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.pinned_events",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let emote = """
            {
              "content": {
                "body": "thinks this is an example emote",
                "format": "org.matrix.custom.html",
                "formatted_body": "thinks <b>this</b> is an example emote",
                "msgtype": "m.emote"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let notice = """
            {
              "content": {
                "body": "This is an example notice",
                "format": "org.matrix.custom.html",
                "formatted_body": "This is an <strong>example</strong> notice",
                "msgtype": "m.notice"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let image = """
            {
              "content": {
                "body": "filename.jpg",
                "info": {
                  "h": 398,
                  "mimetype": "image/jpeg",
                  "size": 31037,
                  "w": 394
                },
                "msgtype": "m.image",
                "url": "mxc://example.org/JWEIFJgwEIhweiWJE"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let file = """
            {
              "content": {
                "body": "something-important.doc",
                "filename": "something-important.doc",
                "info": {
                  "mimetype": "application/msword",
                  "size": 46144
                },
                "msgtype": "m.file",
                "url": "mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let audio = """
            {
              "content": {
                "body": "Bee Gees - Stayin' Alive",
                "info": {
                  "duration": 2140786,
                  "mimetype": "audio/mpeg",
                  "size": 1563685
                },
                "msgtype": "m.audio",
                "url": "mxc://example.org/ffed755USFFxlgbQYZGtryd"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let location = """
            {
              "content": {
                "body": "Big Ben, London, UK",
                "geo_uri": "geo:51.5008,0.1247",
                "info": {
                  "thumbnail_info": {
                    "h": 300,
                    "mimetype": "image/jpeg",
                    "size": 46144,
                    "w": 300
                  },
                  "thumbnail_url": "mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe"
                },
                "msgtype": "m.location"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let video = """
            {
              "content": {
                "body": "Gangnam Style",
                "info": {
                  "duration": 2140786,
                  "h": 320,
                  "mimetype": "video/mp4",
                  "size": 1563685,
                  "thumbnail_info": {
                    "h": 300,
                    "mimetype": "image/jpeg",
                    "size": 46144,
                    "w": 300
                  },
                  "thumbnail_url": "mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe",
                  "w": 480
                },
                "msgtype": "m.video",
                "url": "mxc://example.org/a526eYUSFFxlgbQYZmo442"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let typing = """
            {
              "content": {
                "user_ids": [
                  "@alice:matrix.org",
                  "@bob:example.com"
                ]
              },
              "type": "m.typing"
            }
            """.data(using: .utf8)!
        
        static let receipt = """
            {
              "content": {
                "$1435641916114394fHBLK:matrix.org": {
                  "m.read": {
                    "@rikj:jki.re": {
                      "ts": 1436451550453
                    }
                  },
                  "m.read.private": {
                    "@self:example.org": {
                      "ts": 1661384801651
                    }
                  }
                }
              },
              "type": "m.receipt"
            }
            """.data(using: .utf8)!
        
        static let reaction = """
            {
                "type": "m.reaction",
                "sender": "@matthew:matrix.org",
                "content": {
                    "m.relates_to": {
                        "rel_type": "m.annotation",
                        "event_id": "$some_event_id",
                        "key": "👍"
                    }
                },
                "unsigned": {
                    "annotation_count": 1234,
                }
            }
            """.data(using: .utf8)!
        
        static let fullyRead = """
            {
              "content": {
                "event_id": "$someplace:example.org"
              },
              "type": "m.fully_read"
            }
            """.data(using: .utf8)!
        
        static let presence = """
            {
              "content": {
                "avatar_url": "mxc://localhost/wefuiwegh8742w",
                "currently_active": false,
                "last_active_ago": 2478593,
                "presence": "online",
                "status_msg": "Making cupcakes"
              },
              "sender": "@example:localhost",
              "type": "m.presence"
            }
            """.data(using: .utf8)!
        
        static let encryption = """
            {
              "content": {
                "algorithm": "m.megolm.v1.aes-sha2",
                "rotation_period_ms": 604800000,
                "rotation_period_msgs": 100
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.encryption",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let encrypted1 = """
            {
              "content": {
                "algorithm": "m.megolm.v1.aes-sha2",
                "ciphertext": "AwgAEnACgAkLmt6qF84IK++J7UDH2Za1YVchHyprqTqsg...",
                "device_id": "RJYKSTBOIE",
                "sender_key": "IlRMeOPX2e0MurIyfWEucYBRVOEEUMrOHqn/8mLqMjA",
                "session_id": "X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.encrypted",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let encrypted2 = """
            {
              "content": {
                "algorithm": "m.olm.v1.curve25519-aes-sha2",
                "ciphertext": {
                  "7qZcfnBmbEGzxxaWfBjElJuvn7BZx+lSz/SvFrDF/z8": {
                    "body": "AwogGJJzMhf/S3GQFXAOrCZ3iKyGU5ZScVtjI0KypTYrW...",
                    "type": 0
                  }
                },
                "sender_key": "Szl29ksW/L8yZGWAX+8dY1XyFi+i5wm+DRhTGkbMiwU"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.encrypted",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let key = """
            {
              "content": {
                "algorithm": "m.megolm.v1.aes-sha2",
                "room_id": "!Cuyf34gef24t:localhost",
                "session_id": "X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ",
                "session_key": "AgAAAADxKHa9uFxcXzwYoNueL5Xqi69IkD4sni8LlfJL7qNBEY..."
              },
              "type": "m.room_key"
            }
            """.data(using: .utf8)!
        
        static let keyRequest1 = """
            {
              "content": {
                "action": "request_cancellation",
                "request_id": "1495474790150.19",
                "requesting_device_id": "RJYKSTBOIE"
              },
              "type": "m.room_key_request"
            }
            """.data(using: .utf8)!
        
        static let keyRequest2 = """
            {
              "content": {
                "action": "request",
                "body": {
                  "algorithm": "m.megolm.v1.aes-sha2",
                  "room_id": "!Cuyf34gef24t:localhost",
                  "sender_key": "RF3s+E7RkTQTGF2d8Deol0FkQvgII2aJDf3/Jp5mxVU",
                  "session_id": "X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ"
                },
                "request_id": "1495474790150.19",
                "requesting_device_id": "RJYKSTBOIE"
              },
              "type": "m.room_key_request"
            }
            """.data(using: .utf8)!
        
        static let forwardedRoomKey = """
            {
              "content": {
                "algorithm": "m.megolm.v1.aes-sha2",
                "forwarding_curve25519_key_chain": [
                  "hPQNcabIABgGnx3/ACv/jmMmiQHoeFfuLB17tzWp6Hw"
                ],
                "room_id": "!Cuyf34gef24t:localhost",
                "sender_claimed_ed25519_key": "aj40p+aw64yPIdsxoog8jhPu9i7l7NcFRecuOQblE3Y",
                "sender_key": "RF3s+E7RkTQTGF2d8Deol0FkQvgII2aJDf3/Jp5mxVU",
                "session_id": "X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ",
                "session_key": "AgAAAADxKHa9uFxcXzwYoNueL5Xqi69IkD4sni8Llf..."
              },
              "type": "m.forwarded_room_key"
            }
            """.data(using: .utf8)!
        
        static let dummy = """
            {
              "content": {},
              "type": "m.dummy"
            }
            """.data(using: .utf8)!
        
        static let keyWithheld = """
            {
              "content": {
                "algorithm": "m.megolm.v1.aes-sha2",
                "code": "m.unverified",
                "reason": "Device not verified",
                "room_id": "!Cuyf34gef24t:localhost",
                "sender_key": "RF3s+E7RkTQTGF2d8Deol0FkQvgII2aJDf3/Jp5mxVU",
                "session_id": "X3lUlvLELLYxeTx4yOVu6UDpasGEVO0Jbu+QFnm0cKQ"
              },
              "type": "m.room_key.withheld"
            }
            """.data(using: .utf8)!
        
        static let secretRequest = """
            {
              "content": {
                "action": "request",
                "name": "org.example.some.secret",
                "request_id": "randomly_generated_id_9573",
                "requesting_device_id": "ABCDEFG"
              },
              "type": "m.secret.request"
            }
            """.data(using: .utf8)!
        
        static let secretSend = """
            {
              "content": {
                "request_id": "randomly_generated_id_9573",
                "secret": "ThisIsASecretDon'tTellAnyone"
              },
              "type": "m.secret.send"
            }
            """.data(using: .utf8)!
        
        static let historyVisibility = """
            {
              "content": {
                "history_visibility": "shared"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.history_visibility",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let pushRules = """
            {
              "content": {
                "global": {
                  "content": [
                    {
                      "actions": [
                        "notify",
                        {
                          "set_tweak": "sound",
                          "value": "default"
                        },
                        {
                          "set_tweak": "highlight"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "pattern": "alice",
                      "rule_id": ".m.rule.contains_user_name"
                    }
                  ],
                  "override": [
                    {
                      "actions": [
                        "dont_notify"
                      ],
                      "conditions": [],
                      "default": true,
                      "enabled": false,
                      "rule_id": ".m.rule.master"
                    },
                    {
                      "actions": [
                        "dont_notify"
                      ],
                      "conditions": [
                        {
                          "key": "content.msgtype",
                          "kind": "event_match",
                          "pattern": "m.notice"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "rule_id": ".m.rule.suppress_notices"
                    }
                  ],
                  "room": [],
                  "sender": [],
                  "underride": [
                    {
                      "actions": [
                        "notify",
                        {
                          "set_tweak": "sound",
                          "value": "ring"
                        },
                        {
                          "set_tweak": "highlight",
                          "value": false
                        }
                      ],
                      "conditions": [
                        {
                          "key": "type",
                          "kind": "event_match",
                          "pattern": "m.call.invite"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "rule_id": ".m.rule.call"
                    },
                    {
                      "actions": [
                        "notify",
                        {
                          "set_tweak": "sound",
                          "value": "default"
                        },
                        {
                          "set_tweak": "highlight"
                        }
                      ],
                      "conditions": [
                        {
                          "kind": "contains_display_name"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "rule_id": ".m.rule.contains_display_name"
                    },
                    {
                      "actions": [
                        "notify",
                        {
                          "set_tweak": "sound",
                          "value": "default"
                        },
                        {
                          "set_tweak": "highlight",
                          "value": false
                        }
                      ],
                      "conditions": [
                        {
                          "is": "2",
                          "kind": "room_member_count"
                        },
                        {
                          "key": "type",
                          "kind": "event_match",
                          "pattern": "m.room.message"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "rule_id": ".m.rule.room_one_to_one"
                    },
                    {
                      "actions": [
                        "notify",
                        {
                          "set_tweak": "sound",
                          "value": "default"
                        },
                        {
                          "set_tweak": "highlight",
                          "value": false
                        }
                      ],
                      "conditions": [
                        {
                          "key": "type",
                          "kind": "event_match",
                          "pattern": "m.room.member"
                        },
                        {
                          "key": "content.membership",
                          "kind": "event_match",
                          "pattern": "invite"
                        },
                        {
                          "key": "state_key",
                          "kind": "event_match",
                          "pattern": "@alice:example.com"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "rule_id": ".m.rule.invite_for_me"
                    },
                    {
                      "actions": [
                        "notify",
                        {
                          "set_tweak": "highlight",
                          "value": false
                        }
                      ],
                      "conditions": [
                        {
                          "key": "type",
                          "kind": "event_match",
                          "pattern": "m.room.member"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "rule_id": ".m.rule.member_event"
                    },
                    {
                      "actions": [
                        "notify",
                        {
                          "set_tweak": "highlight",
                          "value": false
                        }
                      ],
                      "conditions": [
                        {
                          "key": "type",
                          "kind": "event_match",
                          "pattern": "m.room.message"
                        }
                      ],
                      "default": true,
                      "enabled": true,
                      "rule_id": ".m.rule.message"
                    }
                  ]
                }
              },
              "type": "m.push_rules"
            }
            """.data(using: .utf8)!
        
        static let thirdpartyInvite = """
            {
              "content": {
                "display_name": "Alice Margatroid",
                "key_validity_url": "https://magic.forest/verifykey",
                "public_key": "abc123",
                "public_keys": [
                  {
                    "key_validity_url": "https://magic.forest/verifykey",
                    "public_key": "def456"
                  }
                ]
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "pc98",
              "type": "m.room.third_party_invite",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let guestAccess = """
            {
              "content": {
                "guest_access": "can_join"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.guest_access",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let tag = """
            {
              "content": {
                "tags": {
                  "u.work": {
                    "order": 0.9
                  }
                }
              },
              "type": "m.tag"
            }
            """.data(using: .utf8)!
        
        static let sso = """
            {
              "identity_providers": [
                {
                  "brand": "github",
                  "id": "com.example.idp.github",
                  "name": "GitHub"
                },
                {
                  "icon": "mxc://example.com/abc123",
                  "id": "com.example.idp.gitlab",
                  "name": "GitLab"
                }
              ],
              "type": "m.login.sso"
            }
            """.data(using: .utf8)!
        
        static let direct = """
            {
              "content": {
                "@bob:example.com": [
                  "!abcdefgh:example.com",
                  "!hgfedcba:example.com"
                ]
              },
              "type": "m.direct"
            }
            """.data(using: .utf8)!
        
        static let ignoredUserList = """
            {
              "content": {
                "ignored_users": {
                  "@someone:example.org": {}
                }
              },
              "type": "m.ignored_user_list"
            }
            """.data(using: .utf8)!
        
        static let sticker = """
            {
              "content": {
                "body": "Landing",
                "info": {
                  "h": 200,
                  "mimetype": "image/png",
                  "size": 73602,
                  "thumbnail_info": {
                    "h": 200,
                    "mimetype": "image/png",
                    "size": 73602,
                    "w": 140
                  },
                  "thumbnail_url": "mxc://matrix.org/sHhqkFCvSkFwtmvtETOtKnLP",
                  "w": 140
                },
                "url": "mxc://matrix.org/sHhqkFCvSkFwtmvtETOtKnLP"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.sticker",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let serverACL = """
            {
              "content": {
                "allow": [
                  "*"
                ],
                "allow_ip_literals": false,
                "deny": [
                  "*.evil.com",
                  "evil.com"
                ]
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.server_acl",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let tombstone = """
            {
              "content": {
                "body": "This room has been replaced",
                "replacement_room": "!newroom:example.org"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.tombstone",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let serverNotice = """
            {
              "content": {
                "admin_contact": "mailto:server.admin@example.org",
                "body": "Human-readable message to explain the notice",
                "limit_type": "monthly_active_user",
                "msgtype": "m.server_notice",
                "server_notice_type": "m.server_notice.usage_limit_reached"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let policyRuleUser = """
            {
              "content": {
                "entity": "@alice*:example.org",
                "reason": "undesirable behaviour",
                "recommendation": "m.ban"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "rule:@alice*:example.org",
              "type": "m.policy.rule.user",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let policyRuleRoom = """
            {
              "content": {
                "entity": "#*:example.org",
                "reason": "undesirable content",
                "recommendation": "m.ban"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "rule:#*:example.org",
              "type": "m.policy.rule.room",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let policyRuleServer = """
            {
              "content": {
                "entity": "*.example.org",
                "reason": "undesirable engagement",
                "recommendation": "m.ban"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "rule:*.example.org",
              "type": "m.policy.rule.server",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let spaceChild = """
            {
              "content": {
                "order": "lexicographically_compare_me",
                "suggested": true,
                "via": [
                  "example.org",
                  "other.example.org"
                ]
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "!roomid:example.org",
              "type": "m.space.child",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
        
        static let spaceParent = """
            {
              "content": {
                "canonical": true,
                "via": [
                  "example.org",
                  "other.example.org"
                ]
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
              "sender": "@example:example.org",
              "state_key": "!parent_roomid:example.org",
              "type": "m.space.parent",
              "unsigned": {
                "age": 1234
              }
            }
            """.data(using: .utf8)!
    }
    
    // MARK: Room Keys
    struct RoomKeys {
        static let changes = """
            {
              "changed": [
                "@alice:example.com",
                "@bob:example.org"
              ],
              "left": [
                "@clara:example.com",
                "@doug:example.org"
              ]
            }
            """.data(using: .utf8)!
        
        static let claim = """
            {
              "one_time_keys": {
                "@alice:example.com": {
                  "JLAFKJWSCS": {
                    "signed_curve25519:AAAAHg": {
                      "key": "zKbLg+NrIjpnagy+pIY6uPL4ZwEG2v+8F9lmgsnlZzs",
                      "signatures": {
                        "@alice:example.com": {
                          "ed25519:JLAFKJWSCS": "FLWxXqGbwrb8SM3Y795eB6OA8bwBcoMZFXBqnTn58AYWZSqiD45tlBVcDa2L7RwdKXebW/VzDlnfVJ+9jok1Bw"
                        }
                      }
                    }
                  }
                }
              }
            }
            """.data(using: .utf8)!
        
        static let query = """
            {
              "device_keys": {
                "@alice:example.com": {
                  "JLAFKJWSCS": {
                    "algorithms": [
                      "m.olm.v1.curve25519-aes-sha2",
                      "m.megolm.v1.aes-sha2"
                    ],
                    "device_id": "JLAFKJWSCS",
                    "keys": {
                      "curve25519:JLAFKJWSCS": "3C5BFWi2Y8MaVvjM8M22DBmh24PmgR0nPvJOIArzgyI",
                      "ed25519:JLAFKJWSCS": "lEuiRJBit0IG6nUf5pUzWTUEsRVVe/HJkoKuEww9ULI"
                    },
                    "signatures": {
                      "@alice:example.com": {
                        "ed25519:JLAFKJWSCS": "dSO80A01XiigH3uBiDVx/EjzaoycHcjq9lfQX0uWsqxl2giMIiSPR8a4d291W1ihKJL/a+myXS367WT6NAIcBA"
                      }
                    },
                    "unsigned": {
                      "device_display_name": "Alice's mobile phone"
                    },
                    "user_id": "@alice:example.com"
                  }
                }
              },
              "master_keys": {
                "@alice:example.com": {
                  "keys": {
                    "ed25519:base64+master+public+key": "base64+master+public+key"
                  },
                  "usage": [
                    "master"
                  ],
                  "user_id": "@alice:example.com"
                }
              },
              "self_signing_keys": {
                "@alice:example.com": {
                  "keys": {
                    "ed25519:base64+self+signing+public+key": "base64+self+signing+master+public+key"
                  },
                  "signatures": {
                    "@alice:example.com": {
                      "ed25519:base64+master+public+key": "signature+of+self+signing+key"
                    }
                  },
                  "usage": [
                    "self_signing"
                  ],
                  "user_id": "@alice:example.com"
                }
              },
              "user_signing_keys": {
                "@alice:example.com": {
                  "keys": {
                    "ed25519:base64+user+signing+public+key": "base64+user+signing+master+public+key"
                  },
                  "signatures": {
                    "@alice:example.com": {
                      "ed25519:base64+master+public+key": "signature+of+user+signing+key"
                    }
                  },
                  "usage": [
                    "user_signing"
                  ],
                  "user_id": "@alice:example.com"
                }
              }
            }
            """.data(using: .utf8)!
        
        static let version = """
            {
              "algorithm": "m.megolm_backup.v1.curve25519-aes-sha2",
              "auth_data": {
                "public_key": "abcdefg",
                "signatures": {
                  "@alice:example.org": {
                    "ed25519:deviceid": "signature"
                  }
                }
              },
              "count": 42,
              "etag": "anopaquestring",
              "version": "1"
            }
            """.data(using: .utf8)!
        
        static let keys = """
            {
              "rooms": {
                "!room:example.org": {
                  "sessions": {
                    "sessionid1": {
                      "first_message_index": 1,
                      "forwarded_count": 0,
                      "is_verified": true,
                      "session_data": {
                        "ciphertext": "base64+ciphertext+of+JSON+data",
                        "ephemeral": "base64+ephemeral+key",
                        "mac": "base64+mac+of+ciphertext"
                      }
                    }
                  }
                }
              }
            }
            """.data(using: .utf8)!
        

    }
    
    // MARK: Thirdparty
    struct Thirdparty {
        static let locationProtocol = """
            [
              {
                "alias": "#freenode_#matrix:matrix.org",
                "fields": {
                  "channel": "#matrix",
                  "network": "freenode"
                },
                "protocol": "irc"
              }
            ]
            """.data(using: .utf8)!
        
        static let protocol1 = """
            {
              "field_types": {
                "channel": {
                  "placeholder": "#foobar",
                  "regexp": "#[^\\s]+"
                },
                "network": {
                  "placeholder": "irc.example.org",
                  "regexp": "([a-z0-9]+\\.)*[a-z0-9]+"
                },
                "nickname": {
                  "placeholder": "username",
                  "regexp": "[^\\s#]+"
                }
              },
              "icon": "mxc://example.org/aBcDeFgH",
              "instances": [
                {
                  "desc": "Freenode",
                  "fields": {
                    "network": "freenode"
                  },
                  "icon": "mxc://example.org/JkLmNoPq",
                  "network_id": "freenode"
                }
              ],
              "location_fields": [
                "network",
                "channel"
              ],
              "user_fields": [
                "network",
                "nickname"
              ]
            }
            """.data(using: .utf8)!
        
        static let protocols = """
            {
              "gitter": {
                "field_types": {
                  "room": {
                    "placeholder": "matrix-org/matrix-doc",
                    "regexp": "[^\\s]+\\/[^\\s]+"
                  },
                  "username": {
                    "placeholder": "@username",
                    "regexp": "@[^\\s]+"
                  }
                },
                "instances": [
                  {
                    "desc": "Gitter",
                    "fields": {},
                    "icon": "mxc://example.org/zXyWvUt",
                    "network_id": "gitter"
                  }
                ],
                "location_fields": [
                  "room"
                ],
                "user_fields": [
                  "username"
                ]
              },
              "irc": {
                "field_types": {
                  "channel": {
                    "placeholder": "#foobar",
                    "regexp": "#[^\\s]+"
                  },
                  "network": {
                    "placeholder": "irc.example.org",
                    "regexp": "([a-z0-9]+\\.)*[a-z0-9]+"
                  },
                  "nickname": {
                    "placeholder": "username",
                    "regexp": "[^\\s]+"
                  }
                },
                "icon": "mxc://example.org/aBcDeFgH",
                "instances": [
                  {
                    "desc": "Freenode",
                    "fields": {
                      "network": "freenode.net"
                    },
                    "icon": "mxc://example.org/JkLmNoPq",
                    "network_id": "freenode"
                  }
                ],
                "location_fields": [
                  "network",
                  "channel"
                ],
                "user_fields": [
                  "network",
                  "nickname"
                ]
              }
            }
            """.data(using: .utf8)!
        
        static let user = """
            [
              {
                "fields": {
                  "user": "jim"
                },
                "protocol": "gitter",
                "userid": "@_gitter_jim:matrix.org"
              }
            ]
            """.data(using: .utf8)!
    }
    
    
    // MARK: Endpoints
    static let wellKnown = """
        {
            "m.homeserver": {
              "base_url": "https://matrix.example.com"
            },
            "m.identity_server": {
              "base_url": "https://identity.example.com"
            },
            "org.example.custom.property": {
              "app_url": "https://custom.app.example.org"
            }
        }
        """.data(using: .utf8)!
    
    static let versions = """
        {
          "unstable_features": {
            "org.example.my_feature": true
          },
          "versions": [
            "r0.0.1",
            "v1.1"
          ]
        }
        """.data(using: .utf8)!
    
    // Also register endpoing
    static let login = """
        {
          "access_token": "abc123",
          "device_id": "GHTYAJCE",
          "expires_in_ms": 60000,
          "refresh_token": "def456",
          "user_id": "@cheeky_monkey:matrix.org",
          "well_known": {
            "m.homeserver": {
              "base_url": "https://example.org"
            },
            "m.identity_server": {
              "base_url": "https://id.example.org"
            }
          }
        }
        """.data(using: .utf8)!
    
    static let password = """
        {
          "completed": [
            "example.type.foo"
          ],
          "flows": [
            {
              "stages": [
                "example.type.foo"
              ]
            }
          ],
          "params": {
            "example.type.baz": {
              "example_key": "foobar"
            }
          },
          "session": "xxxxxxyz"
        }
        """.data(using: .utf8)!
    
    static let filter = """
        {
          "event_fields": [
            "type",
            "content",
            "sender"
          ],
          "event_format": "client",
          "presence": {
            "not_senders": [
              "@alice:example.com"
            ],
            "types": [
              "m.presence"
            ]
          },
          "room": {
            "ephemeral": {
              "not_rooms": [
                "!726s6s6q:example.com"
              ],
              "not_senders": [
                "@spam:example.com"
              ],
              "types": [
                "m.receipt",
                "m.typing"
              ]
            },
            "state": {
              "not_rooms": [
                "!726s6s6q:example.com"
              ],
              "types": [
                "m.room.*"
              ]
            },
            "timeline": {
              "limit": 10,
              "not_rooms": [
                "!726s6s6q:example.com"
              ],
              "not_senders": [
                "@spam:example.com"
              ],
              "types": [
                "m.room.message"
              ]
            }
          }
        }
        """.data(using: .utf8)!
        
    // Modifications
    // 1. Removed the custom entries with other data defined in the spec
    // 2. Removed 'room_id' entry for rooms.join.state and in rooms.join.timeline as the spec
    //    specifically states that the type 'ClientEventWithoutRoomID' does not specify a room id
    // 3. Changed userID @example:localhost to add a TLD, as the assumption is that all matrix
    //    will have a valid domain name
    static let sync = """
        {
          "account_data": {
            "events": [
                {
                  "content": {
                    "tags": {
                      "u.work": {
                        "order": 0.9
                      }
                    }
                  },
                  "type": "m.tag"
                }
            ]
          },
          "next_batch": "s72595_4483_1934",
          "presence": {
            "events": [
              {
                "content": {
                  "avatar_url": "mxc://localhost/wefuiwegh8742w",
                  "currently_active": false,
                  "last_active_ago": 2478593,
                  "presence": "online",
                  "status_msg": "Making cupcakes"
                },
                "sender": "@example:localhost.com",
                "type": "m.presence"
              }
            ]
          },
          "rooms": {
            "invite": {
              "!696r7674:example.com": {
                "invite_state": {
                  "events": [
                    {
                      "content": {
                        "name": "My Room Name"
                      },
                      "sender": "@alice:example.com",
                      "state_key": "",
                      "type": "m.room.name"
                    },
                    {
                      "content": {
                        "membership": "invite"
                      },
                      "sender": "@alice:example.com",
                      "state_key": "@bob:example.com",
                      "type": "m.room.member"
                    }
                  ]
                }
              }
            },
            "join": {
              "!726s6s6q:example.com": {
                "account_data": {
                  "events": [
                    {
                      "content": {
                        "tags": {
                          "u.work": {
                            "order": 0.9
                          }
                        }
                      },
                      "type": "m.tag"
                    }
                  ]
                },
                "ephemeral": {
                  "events": [
                    {
                      "content": {
                        "user_ids": [
                          "@alice:matrix.org",
                          "@bob:example.com"
                        ]
                      },
                      "type": "m.typing"
                    },
                    {
                      "content": {
                        "$1435641916114394fHBLK:matrix.org": {
                          "m.read": {
                            "@rikj:jki.re": {
                              "ts": 1436451550453
                            }
                          },
                          "m.read.private": {
                            "@self:example.org": {
                              "ts": 1661384801651
                            }
                          }
                        }
                      },
                      "type": "m.receipt"
                    }
                  ]
                },
                "state": {
                  "events": [
                    {
                      "content": {
                        "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                        "displayname": "Alice Margatroid",
                        "membership": "join",
                        "reason": "Looking for support"
                      },
                      "event_id": "$143273582443PhrSn:example.org",
                      "origin_server_ts": 1432735824653,
                      "sender": "@example:example.org",
                      "state_key": "@alice:example.org",
                      "type": "m.room.member",
                      "unsigned": {
                        "age": 1234
                      }
                    }
                  ]
                },
                "summary": {
                  "m.heroes": [
                    "@alice:example.com",
                    "@bob:example.com"
                  ],
                  "m.invited_member_count": 0,
                  "m.joined_member_count": 2
                },
                "timeline": {
                  "events": [
                    {
                      "content": {
                        "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                        "displayname": "Alice Margatroid",
                        "membership": "join",
                        "reason": "Looking for support"
                      },
                      "event_id": "$143273582443PhrSn:example.org",
                      "origin_server_ts": 1432735824653,
                      "sender": "@example:example.org",
                      "state_key": "@alice:example.org",
                      "type": "m.room.member",
                      "unsigned": {
                        "age": 1234
                      }
                    },
                    {
                      "content": {
                        "body": "This is an example text message",
                        "format": "org.matrix.custom.html",
                        "formatted_body": "<b>This is an example text message</b>",
                        "msgtype": "m.text"
                      },
                      "event_id": "$143273582443PhrSn:example.org",
                      "origin_server_ts": 1432735824653,
                      "sender": "@example:example.org",
                      "type": "m.room.message",
                      "unsigned": {
                        "age": 1234
                      }
                    }
                  ],
                  "limited": true,
                  "prev_batch": "t34-23535_0_0"
                },
                "unread_notifications": {
                  "highlight_count": 1,
                  "notification_count": 5
                },
                "unread_thread_notifications": {
                  "$threadroot": {
                    "highlight_count": 3,
                    "notification_count": 6
                  }
                }
              }
            },
            "knock": {
              "!223asd456:example.com": {
                "knock_state": {
                  "events": [
                    {
                      "content": {
                        "name": "My Room Name"
                      },
                      "sender": "@alice:example.com",
                      "state_key": "",
                      "type": "m.room.name"
                    },
                    {
                      "content": {
                        "membership": "knock"
                      },
                      "sender": "@bob:example.com",
                      "state_key": "@bob:example.com",
                      "type": "m.room.member"
                    }
                  ]
                }
              }
            },
            "leave": {}
          }
        }
        """.data(using: .utf8)!
    
    static let syncExt = """
        {
          "next_batch": "s72595_4483_1934",
          "rooms": {"leave": {}, "join": {}, "invite": {}},
          "to_device": {
            "events": [
              {
                "sender": "@alice:example.com",
                "type": "m.new_device",
                "content": {
                  "device_id": "XYZABCDE",
                  "rooms": ["!726s6s6q:example.com"]
                }
              }
            ]
          }
        }
        """.data(using: .utf8)!
        
    static let roomMembers = """
        {
          "chunk": [
            {
              "content": {
                "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                "displayname": "Alice Margatroid",
                "membership": "join",
                "reason": "Looking for support"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "state_key": "@alice:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1234
              }
            }
          ]
        }
        """.data(using: .utf8)!
    
    static let roomState = """
        [
          {
            "content": {
              "join_rule": "public"
            },
            "event_id": "$143273582443PhrSn:example.org",
            "origin_server_ts": 1432735824653,
            "room_id": "!636q39766251:example.com",
            "sender": "@example:example.org",
            "state_key": "",
            "type": "m.room.join_rules",
            "unsigned": {
              "age": 1234
            }
          },
          {
            "content": {
              "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
              "displayname": "Alice Margatroid",
              "membership": "join",
              "reason": "Looking for support"
            },
            "event_id": "$143273582443PhrSn:example.org",
            "origin_server_ts": 1432735824653,
            "room_id": "!636q39766251:example.com",
            "sender": "@example:example.org",
            "state_key": "@alice:example.org",
            "type": "m.room.member",
            "unsigned": {
              "age": 1234
            }
          },
          {
            "content": {
              "creator": "@example:example.org",
              "m.federate": true,
              "predecessor": {
                "event_id": "$something:example.org",
                "room_id": "!oldroom:example.org"
              },
              "room_version": "1"
            },
            "event_id": "$143273582443PhrSn:example.org",
            "origin_server_ts": 1432735824653,
            "room_id": "!636q39766251:example.com",
            "sender": "@example:example.org",
            "state_key": "",
            "type": "m.room.create",
            "unsigned": {
              "age": 1234
            }
          },
          {
            "content": {
              "ban": 50,
              "events": {
                "m.room.name": 100,
                "m.room.power_levels": 100
              },
              "events_default": 0,
              "invite": 50,
              "kick": 50,
              "notifications": {
                "room": 20
              },
              "redact": 50,
              "state_default": 50,
              "users": {
                "@example:localhost": 100
              },
              "users_default": 0
            },
            "event_id": "$143273582443PhrSn:example.org",
            "origin_server_ts": 1432735824653,
            "room_id": "!636q39766251:example.com",
            "sender": "@example:example.org",
            "state_key": "",
            "type": "m.room.power_levels",
            "unsigned": {
              "age": 1234
            }
          }
        ]
        """.data(using: .utf8)!
    
    static let messages = """
        {
          "chunk": [
            {
              "content": {
                "body": "This is an example text message",
                "format": "org.matrix.custom.html",
                "formatted_body": "<b>This is an example text message</b>",
                "msgtype": "m.text"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            },
            {
              "content": {
                "name": "The room name"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.name",
              "unsigned": {
                "age": 1234
              }
            },
            {
              "content": {
                "body": "Gangnam Style",
                "info": {
                  "duration": 2140786,
                  "h": 320,
                  "mimetype": "video/mp4",
                  "size": 1563685,
                  "thumbnail_info": {
                    "h": 300,
                    "mimetype": "image/jpeg",
                    "size": 46144,
                    "w": 300
                  },
                  "thumbnail_url": "mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe",
                  "w": 480
                },
                "msgtype": "m.video",
                "url": "mxc://example.org/a526eYUSFFxlgbQYZmo442"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
          ],
          "end": "t47409-4357353_219380_26003_2265",
          "start": "t47429-4392820_219380_26003_2265"
        }
        """.data(using: .utf8)!
    
    static let relations = """
        {
          "chunk": [
            {
              "content": {
                "m.relates_to": {
                  "event_id": "$asfDuShaf7Gafaw",
                  "rel_type": "org.example.my_relation"
                }
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:matrix.org",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
          ],
          "next_batch": "page2_token",
          "prev_batch": "page1_token"
        }
        """.data(using: .utf8)!
    
    static let publicRooms = """
        {
          "chunk": [
            {
              "avatar_url": "mxc://bleecker.street/CHEDDARandBRIE",
              "guest_can_join": false,
              "join_rule": "public",
              "name": "CHEESE",
              "num_joined_members": 37,
              "room_id": "!ol19s:bleecker.street",
              "room_type": "m.space",
              "topic": "Tasty tasty cheese",
              "world_readable": true
            }
          ],
          "next_batch": "p190q",
          "prev_batch": "p1902",
          "total_room_count_estimate": 115
        }
        """.data(using: .utf8)!
    
    static let userDirectorySearch = """
        {
          "limited": false,
          "results": [
            {
              "avatar_url": "mxc://bar.com/foo",
              "display_name": "Foo",
              "user_id": "@foo:bar.com"
            }
          ]
        }
        """.data(using: .utf8)!
    
    static let previewURL = """
        {
          "matrix:image:size": 102400,
          "og:description": "This is a really cool blog post from matrix.org",
          "og:image": "mxc://example.com/ascERGshawAWawugaAcauga",
          "og:image:height": 48,
          "og:image:type": "image/png",
          "og:image:width": 48,
          "og:title": "Matrix Blog Post"
        }
        """.data(using: .utf8)!
    
    static let devices = """
        {
          "devices": [
            {
              "device_id": "QBUAZIFURK",
              "display_name": "android",
              "last_seen_ip": "1.2.3.4",
              "last_seen_ts": 1474491775024
            }
          ]
        }
        """.data(using: .utf8)!
    
    static let pushers = """
        {
          "pushers": [
            {
              "app_display_name": "Appy McAppface",
              "app_id": "face.mcapp.appy.prod",
              "data": {
                "url": "https://example.com/_matrix/push/v1/notify"
              },
              "device_display_name": "Alice's Phone",
              "kind": "http",
              "lang": "en-US",
              "profile_tag": "xyz",
              "pushkey": "Xp/MzCt8/9DcSNE9cuiaoT5Ac55job3TdLSSmtmYl4A="
            }
          ]
        }
        """.data(using: .utf8)!
    
    static let notifications = """
        {
          "next_token": "abcdef",
          "notifications": [
            {
              "actions": [
                "notify"
              ],
              "event": {
                "content": {
                  "body": "This is an example text message",
                  "format": "org.matrix.custom.html",
                  "formatted_body": "<b>This is an example text message</b>",
                  "msgtype": "m.text"
                },
                "event_id": "$143273582443PhrSn:example.org",
                "origin_server_ts": 1432735824653,
                "room_id": "!jEsUZKDJdhlrceRyVU:example.org",
                "sender": "@example:example.org",
                "type": "m.room.message",
                "unsigned": {
                  "age": 1234
                }
              },
              "profile_tag": "hcbvkzxhcvb",
              "read": true,
              "room_id": "!abcdefg:example.com",
              "ts": 1475508881945
            }
          ]
        }
        """.data(using: .utf8)!
    
    static let search = """
        {
          "search_categories": {
            "room_events": {
              "count": 1224,
              "groups": {
                "room_id": {
                  "!qPewotXpIctQySfjSy:localhost": {
                    "next_batch": "BdgFsdfHSf-dsFD",
                    "order": 1,
                    "results": [
                      "$144429830826TWwbB:localhost"
                    ]
                  }
                }
              },
              "highlights": [
                "martians",
                "men"
              ],
              "next_batch": "5FdgFsd234dfgsdfFD",
              "results": [
                {
                  "rank": 0.00424866,
                  "result": {
                    "content": {
                      "body": "This is an example text message",
                      "format": "org.matrix.custom.html",
                      "formatted_body": "<b>This is an example text message</b>",
                      "msgtype": "m.text"
                    },
                    "event_id": "$144429830826TWwbB:localhost",
                    "origin_server_ts": 1432735824653,
                    "room_id": "!qPewotXpIctQySfjSy:localhost",
                    "sender": "@example:example.org",
                    "type": "m.room.message",
                    "unsigned": {
                      "age": 1234
                    }
                  }
                }
              ]
            }
          }
        }
        """.data(using: .utf8)!
    
    static let events = """
        {
          "chunk": [
            {
              "content": {
                "body": "This is an example text message",
                "format": "org.matrix.custom.html",
                "formatted_body": "<b>This is an example text message</b>",
                "msgtype": "m.text"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!somewhere:over.the.rainbow",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
          ],
          "end": "s3457_9_0",
          "start": "s3456_9_0"
        }
        """.data(using: .utf8)!
    
    static let tags = """
        {
          "tags": {
            "m.favourite": {
              "order": 0.1
            },
            "u.Customers": {},
            "u.Work": {
              "order": 0.7
            }
          }
        }
        """.data(using: .utf8)!
    
    static let whois = """
        {
          "devices": {
            "teapot": {
              "sessions": [
                {
                  "connections": [
                    {
                      "ip": "127.0.0.1",
                      "last_seen": 1411996332123,
                      "user_agent": "curl/7.31.0-DEV"
                    },
                    {
                      "ip": "10.0.0.2",
                      "last_seen": 1411996332123,
                      "user_agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.120 Safari/537.36"
                    }
                  ]
                }
              ]
            }
          },
          "user_id": "@peter:rabbit.rocks"
        }
        """.data(using: .utf8)!
    
    static let eventContext = """
        {
          "end": "t29-57_2_0_2",
          "event": {
            "content": {
              "body": "filename.jpg",
              "info": {
                "h": 398,
                "mimetype": "image/jpeg",
                "size": 31037,
                "w": 394
              },
              "msgtype": "m.image",
              "url": "mxc://example.org/JWEIFJgwEIhweiWJE"
            },
            "event_id": "$f3h4d129462ha:example.com",
            "origin_server_ts": 1432735824653,
            "room_id": "!636q39766251:example.com",
            "sender": "@example:example.org",
            "type": "m.room.message",
            "unsigned": {
              "age": 1234
            }
          },
          "events_after": [
            {
              "content": {
                "body": "This is an example text message",
                "format": "org.matrix.custom.html",
                "formatted_body": "<b>This is an example text message</b>",
                "msgtype": "m.text"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
          ],
          "events_before": [
            {
              "content": {
                "body": "something-important.doc",
                "filename": "something-important.doc",
                "info": {
                  "mimetype": "application/msword",
                  "size": 46144
                },
                "msgtype": "m.file",
                "url": "mxc://example.org/FHyPlCeYUSFFxlgbQYZmoEoe"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "type": "m.room.message",
              "unsigned": {
                "age": 1234
              }
            }
          ],
          "start": "t27-54_2_0_2",
          "state": [
            {
              "content": {
                "creator": "@example:example.org",
                "m.federate": true,
                "predecessor": {
                  "event_id": "$something:example.org",
                  "room_id": "!oldroom:example.org"
                },
                "room_version": "1"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "state_key": "",
              "type": "m.room.create",
              "unsigned": {
                "age": 1234
              }
            },
            {
              "content": {
                "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
                "displayname": "Alice Margatroid",
                "membership": "join",
                "reason": "Looking for support"
              },
              "event_id": "$143273582443PhrSn:example.org",
              "origin_server_ts": 1432735824653,
              "room_id": "!636q39766251:example.com",
              "sender": "@example:example.org",
              "state_key": "@alice:example.org",
              "type": "m.room.member",
              "unsigned": {
                "age": 1234
              }
            }
          ]
        }
        """.data(using: .utf8)!
    
    static let hierarchy = """
        {
          "next_batch": "next_batch_token",
          "rooms": [
            {
              "avatar_url": "mxc://example.org/abcdef",
              "canonical_alias": "#general:example.org",
              "children_state": [
                {
                  "content": {
                    "via": [
                      "example.org"
                    ]
                  },
                  "origin_server_ts": 1629413349153,
                  "sender": "@alice:example.org",
                  "state_key": "!a:example.org",
                  "type": "m.space.child"
                }
              ],
              "guest_can_join": false,
              "join_rule": "public",
              "name": "The First Space",
              "num_joined_members": 42,
              "room_id": "!space:example.org",
              "room_type": "m.space",
              "topic": "No other spaces were created first, ever",
              "world_readable": true
            }
          ]
        }
        """.data(using: .utf8)!
    
}
