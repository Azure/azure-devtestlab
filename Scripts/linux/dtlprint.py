# Copyright (c) Microsoft Corporation
# All rights reserved.
#
#
# MIT License
#
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

from __future__ import print_function
import json
import sys


class PrintService:
    """Provides console output services to provide a consistent style output

    Attributes:
        None

    """

    def __init__(self, quiet, verbose):
        self._quiet = quiet
        self._verbose = verbose
        return

    def dumpp(self, propertyBag):
        """Prints the specified Azure RM-style property bag to the console using basic formatting.

        Args:
            propertyBag (dict) - An Azure RM-style name/value object style dictionary to print to the console.
        Returns:
            None

        Examples:

        input:
        {
            "foo" : {
                "type" : "string",
                "value" : "foo value"
            }
        }

        output:
        foo = foo value

        """
        if propertyBag is None:
            return

        for key, value in propertyBag.iteritems():
            print('{0} = {1}'.format(key, value['value']))

        return

    def info(self, text):
        """If not in quiet mode, writes the specified text to stdout.

        Args:
            text (string) - the text to write to stdout
        Returns:
            None

        """

        if not self._quiet:
            print(text)

        return

    def verbose(self, text):
        """If in verbose mode, writes the specified text to stdout.

        Args:
            text (string) - the text to write to stdout
        Returns:
            None

        """

        if self._verbose:
            print(text)

        return

    def error(self, error):
        """Writes the specified error to stderr.

        Args:
            error (string) - The error to write to stderr.
        Returns:
            None

        """
        print(error, file=sys.stderr)

        return

    def warning(self, warning):
        """Writes the specified warning to stdout as a warning.

        Args:
            warning (string) - The warning to write to stdout.
        Returns:
            None

        """
        self.info(self._amberForeground  + 'WARNING: {0}'.format(warning) + self._resetForeground)

        return

    def success(self, text):
        """Writes the specified text as a success message, typically with a green foreground.

        Args:
            text (string) - The text to write.
        Returns:
            None

        """

        self.info(self._greenForeground + text + self._resetForeground)

        return

    def dumps(self, obj):
        """Writes the specified object as a json string.

        Args:
            obj (dict) - The object to write.
        Returns:
            None

        """

        print(json.dumps(obj, indent=4))

    _greenForeground = '\033[92m'
    _amberForeground = '\033[93m'
    _resetForeground = '\033[0m'
    _BOLD = '\033[1m'
    _UNDERLINE = '\033[4m'
