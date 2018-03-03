These dirs reffers to hooks to run when there's fixes needed to do in an installed system of Elive

Dirs structure:
    VERSION:
        x.x.x : is the version of elive reference where the work is uppon to, let's say, that version of elive build includes these fixes, it is used in this way to have a reference and to set the first flag state
        x.x.x.xx : we use another decimal to have clearer references, for example let's say we release 3.0 (3.0.0), every 3.0.0.xx dir will have a migration hook topic (which can have multiple scripts inside the dirs)

        VERSION/user|root : a dir named user or root, which needs to be run by root (admin / system fixes and upgrades), or by user (personal configurations, etc), both can be graphical or not


    FILE TYPES:
        xxxxx.sh:       script to run (optional)
        CHANGELOG.txt:  a changelog to tell the user what has been upgraded/fixed (optional), only plain text is possible for now
