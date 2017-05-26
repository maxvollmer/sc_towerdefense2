sc_towerdefense2 is a map bundle made by Max 'Protector' Vollmer for the game Sven Co-op.

To create your own towerdefense map for Sven Co-op, use the provided Angelscript files and expand the provided map or create your own map.

There are 3 entity types that are at the core of this map type:

towers: Kind of self explanatory, these are the entities bought and upgraded by players.
critters: These are the "monsters" that run along a predefined path and need to be stopped by the players.
workers: These form the core of the whole gameplay, maintaining the money, camera, towers etc. of a player.

Add or modify towers:

* Check out /scripts/maps/sc_towerdefense2/towers.as for the tower base class (all towers must extend this class and override the provided methods).
* Check out the .as-files in /scripts/maps/sc_towerdefense2/towers/ for existing towers.
* Remove includes for unused towers from /scripts/maps/sc_towerdefense2/main.as and add includes for any new ones.
* Make sure your towers are registered in MapInit() with g_CustomEntityFuncs.RegisterCustomEntity.

Assign towers to workers:

* In the map editor create or edit a worker entity and set any towers you want to use (entity keyvalues "tower0", "tower1", "tower2"...).

Define new critter paths:

* In the map editor add, delete or modify info_critter_path entities. The values should be self explanatory. See /scripts/maps/sc_towerdefense2/critterwave.as for how these entities work in detail.

Define critters and waves:

* Simply modify the list of CritterWaves in /scripts/maps/sc_towerdefense2/critterwave.as
** Values are:
*** int critterCount - the amount of critters to spawn (per path!)
*** string model - the model for the critters (e.g. "models/hlclassic/headcrab.mdl")
*** float health - the health critters are spawning with
*** int speed - the speed (units / second) of the critters
*** int flags - see /scripts/maps/sc_towerdefense2/critters.as for list of lags - you may expand them
*** string escapedMonsterClassname - the name of the monster entity being spawned in the player area when critters have escaped. it's health and strength is an accumulation of all escaped critters
*** int money - the amount of money players (or actually: workers) receive after the wave is complete
*** int timeTillNextWave - the time (in seconds) till the next wave begins

Tipps for good performance:
* Use low-poly models (or even sprites) for critters.
* Try to stay below 100 critters at a time.
* Make sure upgrading a tower is far superior to building another tower of the same kind. (This way, when players spam the map with lots of towers, they will lose before performance becomes an issue.)

