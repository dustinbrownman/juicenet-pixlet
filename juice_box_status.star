load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("animation.star", "animation")
load("encoding/base64.star", "base64")

API_BASE = "https://jbv1-api.emotorwerks.com"
API_METHOD = "/box_pin"
SECURE_API_METHOD = "/box_api_secure"
DEFAULT_DEVICE_UUID = "8dbab88c-7156-49c3-ab09-e9f6134d5469"

def main(config):
    api_token = config.str("api_token")
    device_id = config.str("device_id") or DEFAULT_DEVICE_UUID

    if api_token == None:
        return render.Root(child=render.WrappedText("No API token configured"))


    charger_token = get_charger_token(api_token, device_id)
    charger_state = config.str("state") or get_charger_state(api_token, charger_token, device_id)

    columns = [
        render.Column(
            expanded=True,
            main_align="center",
            children=[
                render.Text(
                    content = normalized_state(charger_state),
                ),
            ]
        ),
        render.Column(
            expanded=True,
            main_align="center",
            cross_align="center",
            children=[get_animation(charger_state)],
        ),
    ]

    return render.Root(
        child = render.Box(
            render.Row(
                expanded=True,
                main_align="space_evenly",
                cross_align="center",
                children=columns
            )
        )
    )

def get_charger_token(api_token, device_id):
    cached_token = cache.get("charger_token")

    if cached_token:
        return cached_token

    url = API_BASE + API_METHOD
    payload = {
        "cmd": "get_account_units",
        "device_id": device_id,
        "account_token": api_token,
    }
    response = http.post(url, json_body=payload)

    if response.status_code != 200:
        fail("Failed to get charger state, received status code %s" % response.status_code)

    body = response.json()

    if body["success"] != True:
        fail("Failed to get charger token: " + body["error_message"])

    token = body["units"][0]["token"]

    cache.set("charger_token", token, 60 * 60 * 24)

    return token

def get_charger_state(api_token, charger_token, device_id):
    url = API_BASE + SECURE_API_METHOD
    payload = {
        "cmd": "get_state",
        "device_id": device_id,
        "account_token": api_token,
        "token": charger_token,
    }
    response = http.post(url, json_body=payload)

    if response.status_code != 200:
        fail("Failed to get charger state, received status code %s" % response.status_code)

    body = response.json()

    if body["success"] != True:
        fail("Failed to get charger state: %s" % body["error_message"])


    return body["state"]

def charging_animation():
    return animation.Transformation(
        child=render.Circle(diameter=16, color="#0f0"),
        duration=24,
        delay=0,
        width=16,
        height=16,
        direction="alternate",
        keyframes=[
            animation.Keyframe(
                percentage=0.0,
                transforms=[animation.Scale(x=1, y=1)],
                curve="ease_in_out",
            ),
            animation.Keyframe(
                percentage=1.0,
                transforms=[animation.Scale(x=0.65, y=0.65)],
            )
        ]
    )

def standby_animation():
    return animation.Transformation(
        child=render.Circle(diameter=8, color="#fff"),
        duration=42,
        delay=0,
        width=16,
        height=16,
        origin=animation.Origin(x=1.0, y=1.0),
        direction="alternate",
        keyframes=[
            animation.Keyframe(
                percentage=0.0,
                transforms=[animation.Scale(x=1, y=1), animation.Translate(4, 4)],
                curve="ease_in_out",
            ),
            animation.Keyframe(
                percentage=1.0,
                transforms=[animation.Scale(x=1.5, y=1.5), animation.Translate(4, 4)],
            ),
        ]
    )

def plugged_animation():
    return animation.Transformation(
        child=render.Circle(diameter=12, color="#ff0"),
        duration=18,
        delay=18,
        width=12,
        height=12,
        direction="normal",
        keyframes=[
            animation.Keyframe(
                percentage=0.0,
                transforms=[animation.Scale(x=1, y=1)],
                curve="ease_in_out",
            ),
            animation.Keyframe(
                percentage=0.5,
                transforms=[animation.Scale(x=0.9, y=0.9)],
                curve="ease_in_out",
            ),
            animation.Keyframe(
                percentage=0.0,
                transforms=[animation.Scale(x=1, y=1)],
            ),
        ]
    )

def get_animation(state):
    if state == "charging":
        return charging_animation()
    elif state == "standby":
        return standby_animation()
    elif state == "plugged":
        return plugged_animation()
    else:
        return None

def normalized_state(state):
    if state == "charging":
        return "Charging"
    elif state == "standby":
        return "Standby"
    elif state == "plugged":
        return "Plugged"
    else:
        return "Unknown"