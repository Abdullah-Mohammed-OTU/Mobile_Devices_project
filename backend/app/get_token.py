import os
import json
import pickle
from pathlib import Path
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ["https://www.googleapis.com/auth/gmail.send"]

def main():
    base_dir = Path(__file__).resolve().parent
    credentials_path = base_dir / "credentials.json"
    if not credentials_path.exists():
        raise FileNotFoundError(f"Missing OAuth client file at {credentials_path}.")

    flow = InstalledAppFlow.from_client_secrets_file(
        credentials_path, SCOPES
    )
    creds = flow.run_local_server(port=0)  # Opens browser
    print("\nACCESS TOKEN:\n", creds.token)
    print("\nREFRESH TOKEN:\n", creds.refresh_token)

    # Save to token.json for convenience
    with open(base_dir / "token.json", "w") as token:
        token.write(creds.to_json())

if __name__ == "__main__":
    main()
