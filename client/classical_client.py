import requests

def run():
    r = requests.get("https://localhost")
    print(r.text)

if __name__ == "__main__":
    run()