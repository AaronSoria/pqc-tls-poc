import requests

def run():
    r = requests.get("https://localhost:8443", verify=False)
    print(r.text)

if __name__ == "__main__":
    run()
