from app.main import app


def test_home():
    assert b"Capstone app" in app.test_client().get("/").data


def test_health():
    assert app.test_client().get("/health").data == b"ok"
