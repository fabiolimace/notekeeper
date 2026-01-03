Note Keeper
======================================================

Note Keeper is a simple tool for managing a local collection of notes.

A note is a markdown file in a collection directory.

There are two ways to uniquely identify a note:

* by its relative pathname;
* by a pathname-based UUID.

Dependencies:

* Ubuntu's `mawk`, GNU's `gawk` or Busybox's `awk`.
* Ubuntu's `dash`, GNU's `bash` or Busybox's `ash`.

You must `cd` your collection directory in order to use the tools.

Directory structure
------------------------------------------------------

This is the basic directory structure:

```
COLLECTION
└── .notekeeper
    ├── collection.conf
    └── data
```

The `COLLECTION` directory is the base for notes relative pathnames.

The `COLLECTION/.notekeeper` directory is managed by the Note Keeper tools.

Metadata Structure
------------------------------------------------------

The metadata file structure is:

```
uuid: # UUIDv8 of the file path
note: # Path relative to the base directory
hash: # File hash
crdt: # Create date
updt: # Update date
tags: # Comma separated values
```

To Do List
------------------------------------------------------

This is a list of features to be implemented:

* [x] A function to normalize relative paths.
* [x] A function to check whether a link is internal or external.
    - If a link is internal, `link_.dest_` is a UUID, HREF is relative to the file and PATH is relative to the base directory.
    - If a link is external, `link_.dest_` is NULL and HREF is the URL to an external resource and PATH is NULL.
* [x] A function to check if internal links are broken, verifying whether the file pointed by the path exists.
* [x] A function to check if external links may be broken, verifying whether a HTTP request returns 200 (OK) or 404 (NOK).
* [ ] A function to move a file from a path to another, while updating and normalizing links.
* [ ] A function to remove a file from a path to another, while deleting marking links pointing to it as broken.
* [x] Implement a [UUIDv8](https://gist.github.com/fabiolimace/8821bb4635106122898a595e76102d3a)
* [x] History directory to track file changes.
* [ ] Tests for Ubuntu's `dash`, GNU's `bash`, and BusyBox's `ash`.
* [ ] Tests for Ubuntu's `mawk`, GNU's `gawk`, and BusyBox's `awk`.

References for Busybox `awk`:

* https://wiki.alpinelinux.org/wiki/Awk
* https://wiki.alpinelinux.org/wiki/Regex

License
------------------------------------------------------

This project is Open Source software released under the [MIT license](https://opensource.org/licenses/MIT).

