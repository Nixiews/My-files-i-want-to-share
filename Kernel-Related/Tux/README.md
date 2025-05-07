## Hello hello!

I did some search and hopefully it'll help peoples showing Tux after the GRUB booted the correct kernel and OS.

### Kernel config

1. First of all, you'll download a kernel (most recent prefered) from kernel.org.

2. When the kernel is downloaded, extract it.

3. Once extracted, open the directory (example: in /home/user/download) in your console.

4. Run the command ``sudo mv /linux-x.x.x /usr/src/kernels``.

5. Then get into ``/usr/src/kernels/linux-x.x.x`` and open a console there.

6. Run ``sudo make menuconfig`` and go in ``Device Drivers`` > ``Graphics Support`` > ``Frame buffer Devices`` and make sure the correct frame buffers for you GPU/iGPU are activated.

7. Go in ``Device Drivers`` > ``Graphics Support`` > ``Bootup logo`` and make everything activated and then save the config as .config (automaticaly saved like that).

8. Use nano or any text editor to edit .config in ``/usr/src/kernels/linux-x.x.x`` go to the line ``CONFIG_SYSFB_SIMPLEFB`` and make it become ``CONFIG_SYSFB_SIMPLEFB=y`` then save it.

9. Once the config is correctly saved, run ``sudo make && sudo make modules_install && sudo make install`` to compile the kernel.

### GRUB config

Once the kernel compiled, change your GRUB config. To do so :

1. Go in ``/etc/default/``

2. Run ``sudo nano grub``

3. Remove from the line ``GRUB_CMDLINE_LINUX_DEFAULT=""`` the option ``quiet`` and ``splash``, it'll show the kernel exept of black.

4. On the line ``GRUB_CMDLINE_LINUX=""`` add ``vga=795`` (Note: ``vga=795`` is for 1920x1080 screens. To get the correct ``vga=?`` of your monitor check on Internet).

5. Save the config file by doing ``ctrl+s`` and exit nano by doing ``ctrl+x``.

6. Update your GRUB with ``sudo update-grub`` or ``sudo grub-mkconfig -o /boot/grub/grub.cfg``

### If you want to make sure your GRUB and Linux config is correct, in the directory of this file i've dropped the config files.
