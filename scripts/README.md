explainations :
echo is used to write inside a text file
$(date +%H:%M:%S) will make it write the HOUR (%H) the MINUTES (%M) and the SECONDS (%S)
you can remove any but will always need to have a : to separate all of them.
">>" will say where echo will write and tell it to go to line. Either way, use > to make it delete all in the file and write the new thing.
The .desktop file is configured to run each time the PC will run due to the line : ``X-GNOME-Autostart-enabled=true``
``Exec=/home/nixiews/Desktop/BORDEL/scripts/Heurdempc.sh`` is the line where you'll say what file you wanna run. For .sh you don't have to precise anything but, as example, for .py you'll write "python3 /path/to/dot/py/file.py"
The file ``logdedemarage.log`` is the text file where ill see when my PC started
