import os

from dotenv import load_dotenv
from rich import print

load_dotenv()  # local: finds Lesson/.env; deployed: no-op, uses real env vars

# Colab users: comment the two lines above and use Colab Secrets instead:
# from google.colab import userdata
# os.environ["NEBIUS_API_KEY"] = userdata.get("NEBIUS_API_KEY")

assert os.environ.get("NEBIUS_API_KEY"), "Missing NEBIUS_API_KEY in lesson/.env"
print("Keys loaded.")