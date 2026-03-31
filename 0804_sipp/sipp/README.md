<a href="https://scan.coverity.com/projects/5988">
  <img alt="Coverity Scan Build Status"
       src="https://scan.coverity.com/projects/5988/badge.svg"/>
</a>

SIPp - a SIP protocol test tool
Copyright (C) 2003-2020 - The Authors

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program.  If not, see
[http://www.gnu.org/licenses/](http://www.gnu.org/licenses/).

# Documentation

See the `docs/` directory. It should also be available in html format at:
https://sipp.readthedocs.io/en/latest/

Build a local copy using: ``sphinx-build docs _build``

# Building

This is the SIPp package. Please refer to the
[webpage](http://sipp.sourceforge.net/) for details and documentation.

Normally, you should be able to build SIPp by using CMake:

```
cmake .
make
```

_The SIPp master branch (3.7.x) requires a modern C++11 compiler._

There are several optional flags to enable features (SIP-over-TLS,
SIP-over-SCTP, media playback from PCAP files and the GNU Scientific
Libraries for random distributions):

```
cmake . -DUSE_SSL=1 -DUSE_SCTP=1 -DUSE_PCAP=1 -DUSE_GSL=1
```

## Static builds

SIPp can be built into a single static binary, removing the need for
libraries to exist on the target system and maximising portability.

This is a [fairly complicated
process](https://medium.com/@neunhoef/static-binaries-for-a-c-application-f7c76f8041cf),
and for now, it only works on Alpine Linux.

To build a static binary, pass `-DBUILD_STATIC=1` to cmake.

Two Alpine-based `Dockerfile`s are provided, which can be used as a
build-environment.  Use either `Dockerfile` or `Dockerfile.full` in
the following commands:

```
git submodule update --init
docker build -t sipp -f docker/Dockerfile --output=. --target=bin .
```

# Support

I try and be responsive to issues raised on Github, and there's [a
reasonably active mailing
list](https://lists.sourceforge.net/lists/listinfo/sipp-users).

# Making a release

* Update CHANGES.md. Tag release. Do a build.
* Make `sipp.1` by calling:
    ```
    help2man --output=sipp.1 -v -v --no-info \
      --name='SIP testing tool and traffic generator' ./sipp
    ```
* Then:
    ```
    mkdir sipp-$VERSION
    git ls-files -z | tar -c --null \
       --exclude=gmock --exclude=gtest --files-from=- | tar -xC sipp-$VERSION
    cp sipp.1 sipp-$VERSION/
    # check version, and do
    cp ${PROJECT_BINARY_DIR:-.}/version.h sipp-$VERSION/include/
    tar --sort=name --mtime="@$(git log -1 --format=%ct)" \
          --owner=0 --group=0 --numeric-owner \
          -czf sipp-$VERSION.tar.gz sipp-$VERSION
    ```
* Upload to github as "binary". Note that github replaces tilde sign
  (for ~rcX) with a period.
* Create a static binary and upload this to github as well:
    ```
    docker build -t sipp -f docker/Dockerfile --output=. --target=bin .
    ```
* Note that the static build is broken at the moment. See `ldd sipp`.

# Contributing

SIPp is free software, under the terms of the GPL licence (see the
LICENCE.txt file for details). You can contribute to the development of
SIPp and use the standard Github fork/pull request method to integrate
your changes integrate your changes. If you make changes in SIPp,
*PLEASE* follow a few coding rules:

  - Please stay conformant with the current indentation style (4 spaces
    indent, standard Emacs-like indentation). Examples:

    ```
    if (condition) {        /* "{" even if only one instruction */
        f();                /* 4 space indents */
    } else {
        char* p = ptr;      /* C++-style pointer declaration placement */
        g(p);
    }
    ```

  - If possible, check that your changes can be compiled on:
      - Linux,
      - Cygwin,
      - Mac OS X,
      - FreeBSD.
# Case 1:
bash test_suite/scripts/ims_register_test.sh --local-ip 10.18.2.12 --remote-ip 10.18.1.239:5060 --initial-port 10000 --rate 1000 --users 5000 --scenario basic --duration 60 --reg-count 10

# Case 2:
bash test_suite/scripts/ims_call_test.sh --local-ip 10.18.2.12 --remote-ip 10.18.1.239:5060 --users 2 --rate 1 --call-hold 10000 --call-wait 5000 --call-again 1 --auth none

# Case 3:
sipp -sf test_suite/scenarios/ims_register_basic.xml -oocsf test_suite/scenarios/ims_default_response.xml -inf test_suite/config/uas_users.csv -i 10.18.2.12 -p 5062 -t un -r 1 -m 1 -l 1 -d 300 -key reg_period 600000 -key field_file_name test_suite/config/uas_users.csv -max_socket 924 -recv_timeout 10000 -timeout 10 -aa 10.18.1.239:5060

sipp -sf test_suite/scenarios/ims_register_basic.xml -oocsf test_suite/scenarios/ims_default_response.xml -inf test_suite/config/uac_users.csv -i 10.18.2.12 -p 5060 -t un -r 1 -m 1 -l 2 -d 300 -key reg_period 600000 -key field_file_name test_suite/config/uac_users.csv -max_socket 924 -recv_timeout 10000 -timeout 10 -aa 10.18.1.239:5060

sipp -sf /home/sder/work/sipp/test_suite/scenarios/ims_call_uac.xml -inf /home/sder/work/sipp/test_suite/config/uac_users.csv -users 1 -i 10.18.2.12 -p 5060 10.18.1.239:5060 -trace_err -error_file /home/sder/work/sipp/test_suite/logs/call_test/uac/uac_errors.log -trace_msg -message_file /home/sder/work/sipp/test_suite/logs/call_test/uac/uac_messages.log -trace_screen -screen_file /home/sder/work/sipp/test_suite/logs/call_test/uac/uac_screen.log -screen_overwrite true -trace_stat -stf /home/sder/work/sipp/test_suite/logs/call_test/uac/uac_stats.csv -trace_calldebug -calldebug_file /home/sder/work/sipp/test_suite/logs/call_test/uac/uac_calldebug.log -trace_logs -log_file /home/sder/work/sipp/test_suite/logs/call_test/uac/uac_actions.log -trace_rtt -rtt_freq 1 -fd 1 -t tn -aa -timeout 0 -set call_hold_time 5000 -set call_again 1

Thanks,

  Rob Day <rkd@rkd.me.uk>
