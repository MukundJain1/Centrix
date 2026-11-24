from datetime import date

from app.cycle import days_until_payday

from .conftest import PHONE, bearer, register_user

BASELINE = {
    "currency": "₹",
    "categories": [
        {"title": "Monthly Income", "is_income": True, "items": [{"name": "Salary", "amount": 60000}]},
        {
            "title": "Housing",
            "items": [{"name": "Rent", "amount": "15000.50"}, {"name": "Maintenance", "amount": 1000}],
        },
        {"title": "Gym stuff", "is_custom": True, "items": [{"name": "Membership", "amount": 5000}]},
    ],
}


async def test_baseline_roundtrip_and_surplus(client):
    auth = await register_user(client)
    h = bearer(auth)

    empty = await client.get("/v1/baseline", headers=h)
    assert empty.status_code == 200
    assert empty.json()["categories"] == []

    saved = await client.put("/v1/baseline", json=BASELINE, headers=h)
    assert saved.status_code == 200, saved.text
    body = saved.json()
    assert body["monthly_surplus"] == 60000 - 15000.50 - 1000 - 5000
    assert [c["title"] for c in body["categories"]] == ["Monthly Income", "Housing", "Gym stuff"]
    assert body["categories"][1]["items"][0] == {"name": "Rent", "amount": 15000.5}
    assert body["categories"][2]["is_custom"] is True
    assert body["daily_limit"] > 0

    again = await client.get("/v1/baseline", headers=h)
    assert again.json()["categories"] == body["categories"]

    me = await client.get("/v1/auth/me", headers=h)
    assert me.json()["onboarding"] == {"baseline_done": True, "cycle_done": False}


async def test_saving_again_replaces_the_old_baseline(client):
    auth = await register_user(client)
    h = bearer(auth)
    await client.put("/v1/baseline", json=BASELINE, headers=h)

    smaller = {"currency": "$", "categories": [{"title": "Income", "is_income": True, "items": [{"name": "Pay", "amount": 100}]}]}
    r = await client.put("/v1/baseline", json=smaller, headers=h)
    assert r.json()["currency"] == "$"
    assert len(r.json()["categories"]) == 1
    assert r.json()["monthly_surplus"] == 100


async def test_users_cannot_see_each_others_baseline(client):
    a = await register_user(client)
    other = {"dial_code": "+91", "phone": "9123456780", "country_iso": "IN"}
    b = await register_user(client, phone=other)

    await client.put("/v1/baseline", json=BASELINE, headers=bearer(a))
    mine = await client.get("/v1/baseline", headers=bearer(b))
    assert mine.json()["categories"] == []


async def test_negative_amounts_are_rejected(client):
    auth = await register_user(client)
    bad = {"currency": "₹", "categories": [{"title": "x", "items": [{"name": "y", "amount": -5}]}]}
    r = await client.put("/v1/baseline", json=bad, headers=bearer(auth))
    assert r.status_code == 422
    assert r.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_cycle_sets_the_daily_limit(client):
    auth = await register_user(client)
    h = bearer(auth)
    r = await client.put(
        "/v1/cycle",
        json={"payday": 1, "current_balance": 31000, "client_date": "2026-10-28"},
        headers=h,
    )
    assert r.status_code == 200, r.text
    # 28 Oct -> 1 Nov is 4 days
    assert r.json()["daily_limit"] == 7750.0
    assert r.json()["payday"] == 1
    assert r.json()["onboarding"]["cycle_done"] is True

    # Editing the baseline afterwards must not overwrite the payday-based budget.
    await client.put("/v1/baseline", json=BASELINE, headers=h)
    me = await client.get("/v1/auth/me", headers=h)
    assert me.json()["daily_limit"] == 7750.0
    assert me.json()["monthly_surplus"] is not None


def test_days_until_payday():
    assert days_until_payday(date(2026, 10, 28), 1) == 4
    assert days_until_payday(date(2026, 10, 28), 28) == 31  # today is payday -> next month
    assert days_until_payday(date(2026, 10, 28), 30) == 2
    assert days_until_payday(date(2026, 4, 30), 31) == 31   # payday 31 in a 30-day month = the 30th
    assert days_until_payday(date(2026, 12, 20), 5) == 16   # crosses the new year
    assert days_until_payday(date(2026, 1, 31), 31) == 28   # Feb has no 31st -> 28 Feb
