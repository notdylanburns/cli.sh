# cli.sh

cli.sh is a bash tool for creating command line interfaces. The file `cli.sh` is a library of useful bash functions for the cli, handling things such as parsing arguments and printing usage messages.

## Installing cli.sh

Running the `install.sh` script will attempt to copy the necessary files from this repository into `/usr/local/bin`. This usually means you must run the installer as root or using `sudo`. You can also specify a directory to install to as an argument to `install.sh`, eg `./install.sh ~/bin`. The `init-cli.sh` and `cli.sh` files must reside in the same directory, and once a cli project has been created, it will source `cli.sh` from the location that it was when `init-cli.sh` was run, so it is advisable not to move the file. Alternatively, you can copy the `cli.sh` file into your project directory and update the reference to it in the entry point file.

## Creating a cli.sh project

The `init-cli.sh` script is used to create a new cli.sh project. It takes one argument: the name of your cli project, eg `./init-cli mycli`. The project will be initialised in the current directory.

## Structure of a cli.sh project

This is the structure of a sample project, called `example-cli`.
```
example-cli
├── cmd
│   ├── command1
│   │   ├── subcommand1.sh
│   │   ├── subcommand1.args
│   │   ├── subcommand2.sh
│   │   └── subcommand2.args
│   ├── command1.sh
│   ├── command1.args
│   ├── command2.sh
│   └── command2.args
├── example-cli
├── example-cli.args
└── example-cli.rc
```

This cli would have the following commands:
```
example-cli command1 subcommand1
example-cli command1 subcommand2
example-cli command2
```

## .args files

.args files represent the flags and positional arguments that a cli will accept. The file consists of defined fields delimeted by ':'.

There are two types of entry in this file
```
1) Positional arguments

    They are formatted as follows

    <argument name>:<is required>::::<short description>:<long description>

    where <is required> is either true or false

2) Flags

    These are parsed by parse_args()
    Flags can appear anywhere in the command line after the sub-command that defines them, but not before

    eg,
        rootCmd: -h
        subCmd: -d

    then,
        rootCmd -h subCmd
        rootCmd subCmd -h
    are both valid

    but
        rootCmd -d subCmd
    is not.

    They are formatted as follows

    <variable name>:<is required>:<short form>:<long form>:<argument count>:<short description>:<long description>

    where,
        <variable name> is the name of a bash variable to contain the result of parsing this flag
        <is required> is either true or false
        <short form> is a short version of the flag, eg -h or -f
        <long form> is a long version of the flag, eg --help or --file
        <argument count> is the number of args this flag takes.
                         if <argument count> is 0, the bash variable <variable name>
                         will be populated by the flag string if it is present, else the
                         varaible will be empty

                         if <argument count> is 1, the bash variable <variable name>
                         will be populated by the string of the first argument after
                         the flag

                         if <argument count> is greater than 1, the bash variable <variable name>
                         will be an array of <argument count> args after the flag
```