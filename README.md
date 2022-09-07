# ASS-Damage-Logger
Proof-of-concept packet damage logger for anime game with Akebi-Sniffer-Scripting

## Usage
- Setting up Akebi and Sniffer
  - Build [Akebi](https://github.com/Akebi-Group/Akebi-GC) or get the latest artifact from their [actions](https://github.com/Akebi-Group/Akebi-GC/actions).
  - Build my fork of [Akebi-Sniffer](https://github.com/RainAfterDark/Akebi-PacketSniffer) or download my [unofficial release](https://github.com/RainAfterDark/Akebi-PacketSniffer/releases/tag/Unofficial). (until my [PR](https://github.com/Akebi-Group/Akebi-PacketSniffer/pull/10) gets merged)
  - There should be a tutorial on how to setup the sniffer over there, but for protos, you can get [Sorapointa's](https://github.com/Sorapointa/Sorapointa-Protos).
  - After injecting the game with Akebi, open the menu, go to settings, and all the way down, turn on "Capturing".
  - Open up the sniffer, set-up your protos and load the script `damage_logger.lua`.
  
- Using the script
  - I've made the script work specifically with packet level filter **ENABLED** to save memory, since we don't need every packet getting saved.
  - I recommend that you first disconnect the pipe in settings while preparing to log a rotation, and clearing packets (right click any packet in the capture window and a context menu should open).
  - Whenever you're ready, make sure that you connect the pipe again **BEFORE** changing scenes or swapping teams. This is to capture the packet telling the server the characters you're using, which the script needs.
  - Do stuff once you're connected.
  - To actually "log" the damage, you can disconnect the pipe again now (to save memory). If you see packets are still flooding, check the packet queue size on the menu bar.
  - Once the queue size is 0, now you have to **DISABLE** packet level filter and then hit apply to generate logs.
  - From here you can clear your saved packets again to save memory and do it over again. Remember to turn packet level filter back **ON**.
  - Clear the console by reloading the script. You can also mess with the configs. Do whatever.
  
  I have to mention that crashes after saving changes to the code can happen **very frequently** for some reason I can't quite understand, so just be warned. I think it helps reloading before applying changes to the script.
  
  ## Findings/Wiki/How It Works/What Doesn't Work/What Should Work section: TODO
  
  Also if you have nothing else to do help me set a color code for individual characters (or an entirely new color scheme)! Just edit output/theme.lua :)
