## Note: This is already quite outdated. I've made a much better and easier to use version of this in [AGDL](https://github.com/RainAfterDark)

# ASS-Damage-Logger
Proof-of-concept packet damage logger for anime game with Akebi-Sniffer-Scripting (ASS)

## Usage
- Setting up Akebi and Sniffer
  - Get the latest release of [Akebi](https://github.com/Akebi-Group/Akebi-GC).
  - Build my fork of [Akebi-PacketSniffer](https://github.com/RainAfterDark/Akebi-PacketSniffer) or download my [unofficial release](https://github.com/RainAfterDark/Akebi-PacketSniffer/releases). (until my [PR](https://github.com/Akebi-Group/Akebi-PacketSniffer/pull/10) gets merged)
  - After injecting the game with Akebi, open the menu, go to settings, and all the way down, turn on "Capturing".
  - Open up the sniffer, set-up your protos (you can get [Sorapointa's](https://github.com/Sorapointa/Sorapointa-Protos)) and load the script `damage_logger.lua` from wherever you may have placed it. A simple video tutorial for setting up the sniffer should be in the repo's README.
  
- Using the script
  - `git clone https://github.com/RainAfterDark/ASS-Damage-Logger.git`
  - Initial step: Add the script to the main filter and then press "Apply".
  - Method 1: Realtime logging **without** saving packets
    - In the settings window, enable "Pass-through mode" (requires disabling packet level filter).
    - In the script, set the `REALTIME_LOGGING` option to `true` (it's on by default).
    - Load into a scene, change teams, or swap characters in the party setup tab to capture the team update packet (**very important**).
    - Do stuff and see logs output in realtime.
    - This is the least memory consuming method, but with the downside that no packets get saved at all. This means that you can't reapply the filter or reload the script without losing data.
  - Method 2: Realtime logging **with** saving packets
    - Basically the same as the previous method, except pass-through mode is disabled.
    - This is the simplest but the most memory consuming method, only use when you really need to capture every packet.
  - Method 3: Using packet level filter
    - In the settings window, enable "Packet level filter".
    - In the script, set the `REALTIME_LOGGING` option to `false`.
    - I recommend that you first disconnect the pipe in settings while preparing to log a rotation, and clearing packets if there are any (right click any packet in the capture window and a context menu should open, press "Clear"). Reload the script after you do so.
    - Whenever you're ready, make sure that you connect the pipe again **before** changing scenes or swapping teams. This is to capture the packet telling the server the characters you're using, which the script needs.
    - Do stuff once you're connected.
    - You can disconnect the pipe again now (to save memory). To actually "log" the damage, first **disable** packet level filter and then press apply.
    - From here you can clear your saved packets again to save memory and do it over again. Remember to turn packet level filter back **on**.
    - Clear the console by reloading the script. You can also mess with the configs. Do whatever.
    - This was originally the only method, and it's still a good balance between flexibility and memory consumption, if you really need to save packets. Otherwise, the first method should almost always be used.
  
I have to mention that crashes can happen quite frequently for some reason I can't quite understand, moreso when editing the code, so just be warned.
  
## Extra Tools
- Updating/generating data: see `/data/README.md` and relevant scripts.
- `damage_parser.py`: Simple DPS parser and experimental reaction ownership corrector. (not 100% accurate, see code for how it works)
- Excel parser can be found [here](https://docs.google.com/spreadsheets/d/10rxAk7O8MLHZt5jacCHQrdzfP2-hOh-kk7TWJDj71sM/edit?usp=sharing), just clone import your data (as append) or paste your data and then split columns.
 
