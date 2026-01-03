Note Keeper
======================================================

Note Keeper is a set of tools for managing a local collection of notes.

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
    ├── data
    └── html
```

The `COLLECTION` directory is the base for notes relative pathnames.

The `COLLECTION/.notekeeper` directory is managed by the Note Keeper tools.

Metadata Structure
------------------------------------------------------

### Metadata files

The metadata file structure:

```
uuid: # UUIDv8 of the file path
path: # Path relative to the base directory
name: # File name
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
* [x] A script to convert markdown texts to HTML files, placing the output into .notekeeper/html
* [x] A simple script to serve the HTML files in `.notekeeper/html` in the local interface at a specific port.
* [x] A script to generate data about markdown texts, placing the output into .notekeeper/data
* [x] Implement a [UUIDv8](https://gist.github.com/fabiolimace/8821bb4635106122898a595e76102d3a)
* [x] History directory to track file changes.
* [ ] An index page that lists all HTML pages.
* [ ] A search box in the top of the index page.
* [ ] A simple bag of words for searching HTML pages.
* [ ] A simple access counter for HTML page access.
* [ ] A simple change history for each HTML page.
* [ ] Tests for Ubuntu's `dash`, GNU's `bash`, and BusyBox's `ash`.
* [ ] Tests for Ubuntu's `mawk`, GNU's `gawk`, and BusyBox's `awk`.

References for Busybox `awk`:

* https://wiki.alpinelinux.org/wiki/Awk
* https://wiki.alpinelinux.org/wiki/Regex

License
------------------------------------------------------

This project is Open Source software released under the [MIT license](https://opensource.org/licenses/MIT).

