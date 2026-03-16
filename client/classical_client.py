import requests
import urllib3


def run():
    urllib3.disable_warnings()
    r = requests.get("https://localhost:8443", verify=False)
    print(r.text)

if __name__ == "__main__":
    run()
