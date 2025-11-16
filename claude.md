Flutter App - Game Keepr

# Purpose
A mobile Flutter application that can download a board game collection from Board Game Geek, persist it to the phone, allow searching and browsing of owned games as well as tracking the location of the owned game on shelves.
For example, I might have 8 shelves with 8 bays and I want to say that a game is in bay B8 which would be the 2nd shelf, 8th bay. The main feature is that I can scan an NFC chip in the game box that will pull up the game details
and show me where it is

# Instructions
- Create a flutter mobile app that targets iOS
- flutter is available from the command line to execute all flutter commands
- focus on Material design
- Allow writing of game location to NFC
- Allow showing game details when NFC is scanned.
- If state is necessary, use RiverPod.
- Allow sync'ing games from board game geek using their API v2.
- Sync'ing games should be able to update local collection if already exists.
- Allow editing the location of the game from details screen
