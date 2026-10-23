# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
class_name Billing
extends RefCounted
## Coin packs and the purchase hook.
## Real payments need the App Store / Google Play in-app-purchase plugin (and a merchant account).
## Until that is connected `enabled` stays false: nothing is charged and no coins are given.
## When the store plugin confirms a purchase, call Billing.grant(pack_id) - it is the ONLY place coins are credited.

static var enabled := false

const PACKS := [
	{"id": "c500", "coins": 500, "price": "0.99", "bonus": "", "tag": ""},
	{"id": "c1300", "coins": 1300, "price": "1.99", "bonus": "+30%", "tag": ""},
	{"id": "c3500", "coins": 3500, "price": "4.99", "bonus": "+40%", "tag": "popular"},
	{"id": "c8000", "coins": 8000, "price": "9.99", "bonus": "+60%", "tag": ""},
	{"id": "c20000", "coins": 20000, "price": "19.99", "bonus": "+100%", "tag": "best"},
]

const METHODS := [
	{"id": "card", "n": ["Credit / debit card", "بطاقة بنكية"], "sub": "Visa  -  Mastercard"},
	{"id": "apple", "n": ["Apple Pay", "Apple Pay"], "sub": "iPhone"},
	{"id": "google", "n": ["Google Play", "Google Play"], "sub": "Android"},
]


static func pack(id: String) -> Dictionary:
	for p in PACKS:
		if p["id"] == id:
			return p
	return {}


## called by the store plugin after a verified purchase
static func grant(pack_id: String) -> bool:
	var p := pack(pack_id)
	if p.is_empty():
		return false
	Profile.coins += int(p["coins"])
	Profile.save()
	return true
