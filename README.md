# CW3toX

Allows use of Custom Weapons 3 attributes in [Custom Weapons X][].

## Requirements

- [Custom Weapons X][] (X.0.8 rr-50 or newer).
  - This plugin depends on "extended data" functionality.
- Custom Weapons 3: Attributes Module (`cw3/modules/cw3-attributes.smx`) *must be unloaded*.
This plugin reimplements the module's native functionality for Custom Weapons X.
  - This does mean that Custom Weapons 3 will no longer apply CW3 attributes for weapons.

[Custom Weapons X]: https://github.com/nosoop/SM-TFCustomWeaponsX

## Usage

Insert a new `cw3_attributes` section into your weapon configuration under `extdata`, formatted
in the same way as it would be in Custom Weapons 3.

Example weapon configuration entry based on
[the Custom Weapons 3 thread's first post][cw3-post]:

```
"cw3.AdvancedWeaponiserPenetrator"
{
	"name"		"AW - Penetrator"
	"inherits"	"The Huntsman"
	"attributes_game"
	{
		"projectile penetration"				"1"
		"fire rate penalty"						"1.25"
		"sniper aiming movespeed decreased"		"0.5"
	}
	"extdata"
	{
		"cw3_attributes"
		{
			"projectiles bounce"
			{
				"plugin"	"advanced-weaponiser-2-attributes"
				"value"		"2"
			}
		}
	}
}
```

The special `tf2attributes`, `tf2attributes.int`, and `tf2items` plugin values are *not*
supported in this adapter.  You will need to migrate them to the `attributes_game` section of
the configuration.

[cw3-post]: https://forums.alliedmods.net/showthread.php?t=285258

## Caveats

There is no guarantee that all Custom Weapons 3 attributes will work flawlessly with this
plugin.  Any attribute plugins that are timing-dependent (e.g. depending on certain things being
available during certain game events / callbacks) may be broken.

CW3 attribute plugins are force-unloaded / reloaded when this plugin is; instead,
`CW3_OnWeaponRemoved` is called on all slots.

## Building

This project is configured for building via [Ninja][]; see `BUILD.md` for detailed
instructions on how to build it.

If you'd like to use the build system for your own projects,
[the template is available here](https://github.com/nosoop/NinjaBuild-SMPlugin).

[Ninja]: https://ninja-build.org/
