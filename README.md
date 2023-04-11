=encoding UTF-8

=for html <a href="https://badge.fury.io/gh/jddurand%2Fc-tconv"><img src="https://badge.fury.io/gh/jddurand%2Fc-tconv.svg" alt="GitHub version" height="18"></a> <a href="http://opensource.org/licenses/MIT" rel="nofollow noreferrer"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License MIT" height="18"></a> <a href="https://ci.appveyor.com/project/jddurand/c-tconv"><img src="https://ci.appveyor.com/api/projects/status/github/jddurand/c-tconv?branch=master&svg=true&retina=true" alt="AppVeyor CI build status" height="18"></a> <a href="https://github.com/jddurand/c-tconv/actions/workflows/unix.yml"><img src="https://github.com/jddurand/c-tconv/actions/workflows/unix.yml/badge.svg?branch=master" alt="Github Unix workflow build status" height="18"></a> <a href="https://github.com/jddurand/c-tconv/actions/workflows/windows.yml"><img src="https://github.com/jddurand/c-tconv/actions/workflows/windows.yml/badge.svg?branch=master" alt="Github Windows workflow build status" height="18"></a>

# NAME

tconv - iconv-like interface with automatic charset detection

# DESCRIPTION

tconv is a generic interface on charset detection and character conversion implementations. It is not necessary anymore to know in advance the charset: if you do NOT specify, tconv will guess.

Built-in charset detection engines are: cchardet, ICU.
Built-in character conversion engines are: iconv (even on Windows, via win-iconv), ICU.

# SEE ALSO

[iconv(3)](http://man.he.net/man3/iconv), [cchardet](https://pypi.python.org/pypi/cchardet/), [win-iconv](https://github.com/win-iconv/win-iconv), [ICU](http://icu-project.org/)
