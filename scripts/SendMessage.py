#!/usr/bin/env python

# Send message when upload has completed
import telegram
import sys
import datetime
import os

if len(sys.argv) < 10:
  print(sys.argv[0] + " USAGE [ROM NAME] [ROM FOLDER ID] [VERSION] [FILESIZE] [CHANGELOG FILE] [NOTES FILE] [MEGA DECRYPT KEY] [TELEGRAM TOKEN] [TELEGRAM GROUP]")
  sys.exit(1)

rom_name = sys.argv[1]
rom_folder_id = sys.argv[2]
version = sys.argv[3]
filesize = sys.argv[4]
changelog = sys.argv[5]
notes = sys.argv[6]
mega_decrypt_key = sys.argv[7]
telegram_token = sys.argv[8]
telegram_group = sys.argv[9]

bot = telegram.Bot(token=telegram_token)

# Check if rom mega id is valid
if rom_folder_id == "":
  print("Error - ROM FOLDER ID is invalid")
  sys.exit(2)

# Check if changelog file exists
if not os.path.isfile(sys.argv[5]):
  print("Warning - change log file doesn't exist")
  changelog_txt = ""
else:
  with open(changelog, 'r') as file:
    changelog_txt = file.read()

# Check if notes file exists
if not os.path.isfile(sys.argv[6]):
  print ("Warning - notes file doesn't exist")
  notes_txt = ""
else:
  with open(notes, 'r') as file2:
    notes_txt = file2.read()

# Create mega link from id
mega_folder_link = "https://mega.nz/folder/" + rom_folder_id + mega_decrypt_key

# Get current date
x = datetime.datetime.now()
date = x.strftime("%Y %B %d %H:%M")

structure = """ ROM: """ + rom_name + """

📲 New builds available for Galaxy S9 (starltexx), Galaxy S9 Plus (star2ltexx) and Galaxy Note 9 (crownltexx)
👤 by TinyRob & Blast

ℹ️ Version: """ + version + """
📅 Build date: """ + date + """
📎 File size: """ + filesize + """

⬇️  Download now ⬇️

""" + mega_folder_link + """

📃 Changelog 📃

- Synced to latest """ + rom_name + """ sources
- Fixed miscellaneous bugs and issues
""" + changelog_txt + """
Notes:

""" + notes_txt + """- We also recommend using the WhiteWolf Kernel, which works perfectly on our rom

#crownltexx #starltexx #star2ltexx #KeepEvolving """

# Send message to group
bot.send_message(chat_id=telegram_group, text=structure)
