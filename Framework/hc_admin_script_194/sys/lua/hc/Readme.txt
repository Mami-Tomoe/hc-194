
HC CS2D Admin Script
- by Häppy C@mper

  http://hc.tjoho.org
  mailto:hc.cs2d@gmail.com

==========================


Overview
--------

This is a script used for administrating CS2D servers. Commands are invoked
from menus or the say prompt.

Serveraction1 (default F2)  - Command menu
Serveraction2 (default F3)  - Moderator menu
Serveraction3 (default F4)  - Map vote menu

A list of say commands can be found by selecting Help->List Say Commands from
the Command menu. The commands available for a certain user depends on which
category the user belongs to.


User Categories
---------------

There are four categories of registered users handled by the script:

* VIP User
  - users with special privileges
* Moderator Level 1
  - moderates the game
* Moderator Level 2
  - moderates the game, has authority to ban users permanently
* Administrator
  - administers the server and the users

Administrator is the highest level. Users at a certain level automatically has
the privileges of those at a lower level.


Package Structure
-----------------

sys/lua/hc/
           hc.lua     - the main script
           hc.conf    - configuration file
           core/      - core script files
           data/      - persistent data storage
           modules/   - optional script modules
gfx/hc/               - images


Modules
-------

The following modules are optional and can be turned on or off in hc.conf:

automod       - auto moderation (speech and name censoring, anti entrance
              - killing, ...)
chat          - custom say tag and colour
clock         - displays the current time in the hud
maps          - map voting
messaging     - instant and offline messaging
moderation    - manual moderation (slap, kick, ban, ...)
playerattribs - player attributes (helmets)
playerstats   - player statistics
teambalance   - team balancing


Installation Instructions
-------------------------

Unzip the package into the CS2D folder. Note that this will overwrite your
sys/servertransfer.lst and sys/lua/server.lua files!

Edit the file sys/lua/hc/data/config/users.hcu. Replace 12345 with your
U.S.G.N. number:

  12345,Adm,Your Name

If you have an old users.hcu file, use it to replace the one provided by this
package.


Configuration
-------------

The behaviour of the script is controlled by settings defined in the file

  sys/lua/hc/hc.conf

The file uses constant values defined in the following files:

  sys/lua/hc/core/cs2d.lua
  sys/lua/hc/core/constants.lua

The path to the hc directory can be changed by setting hc_dir in server.lua
to a different value. The location of the hc.conf file is controlled in the
same way by the global variable hc_conf.
