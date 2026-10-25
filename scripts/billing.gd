# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Billing
extends RefCounted
## Coin packs and the purchase hook.
## Real payments need the App Store / Google Play in-app-purchase plugin (and a merchant account).
## Until that is connected `enabled` stays false: nothing is charged and no coins are given.
## When the store plugin confirms a purchase, call Billing.grant(pack_id) - it is the ONLY place coins are credited.

static var enabled := false

## coins: $1 = 10,000 (mid-range economy)
const COIN_PACKS := [
	{"id": "c10k", "kind": "coins", "amount": 10000, "price": "1.00", "bonus": "", "tag": ""},
	{"id": "c22k", "kind": "coins", "amount": 22000, "price": "2.00", "bonus": "+10%", "tag": ""},
	{"id": "c60k", "kind": "coins", "amount": 60000, "price": "5.00", "bonus": "+20%", "tag": "popular"},
	{"id": "c130k", "kind": "coins", "amount": 130000, "price": "10.00", "bonus": "+30%", "tag": ""},
	{"id": "c280k", "kind": "coins", "amount": 280000, "price": "20.00", "bonus": "+40%", "tag": "best"},
]
## gems: the same price steps the coin shop used before
const GEM_PACKS := [
	{"id": "g80", "kind": "gems", "amount": 80, "price": "0.99", "bonus": "", "tag": ""},
	{"id": "g170", "kind": "gems", "amount": 170, "price": "1.99", "bonus": "+5%", "tag": ""},
	{"id": "g450", "kind": "gems", "amount": 450, "price": "4.99", "bonus": "+10%", "tag": "popular"},
	{"id": "g950", "kind": "gems", "amount": 950, "price": "9.99", "bonus": "+15%", "tag": ""},
	{"id": "g2000", "kind": "gems", "amount": 2000, "price": "19.99", "bonus": "+25%", "tag": "best"},
]

const METHODS := [
	{"id": "card", "n": ["Credit / debit card", "بطاقة بنكية"], "sub": "Visa  -  Mastercard"},
	{"id": "apple", "n": ["Apple Pay", "Apple Pay"], "sub": "iPhone"},
	{"id": "google", "n": ["Google Play", "Google Play"], "sub": "Android"},
]


static func pack(id: String) -> Dictionary:
	for p in COIN_PACKS + GEM_PACKS:
		if p["id"] == id:
			return p
	return {}


## called by the store plugin after a verified purchase
static func grant(pack_id: String) -> bool:
	var p := pack(pack_id)
	if p.is_empty():
		return false
	if p["kind"] == "gems":
		Profile.gems += int(p["amount"])
	else:
		Profile.coins += int(p["amount"])
	Profile.save()
	return true
