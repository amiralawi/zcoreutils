lower = "abcdefghijklmnopqrstuvwxyz"
upper = lower.upper()
digit = "0123456789"
special = "`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/?"
whitespace = " \t\r"
newline = "\n"

chars_tot = "".join([lower, upper, digit, special, whitespace, newline])
chars_nonewline = "".join([lower, upper, digit, special, whitespace])


import random
import argparse
parser = argparse.ArgumentParser(
    prog="genfile.py",
    description="Creates a file with randomly-generated content",
    epilog="Text at the bottom of help"
)
parser.add_argument("filename")
parser.add_argument("-n", "--nbytes", help="defaults to randint(32, 1024)", type=int, required=False)
#parser.add_argument("-l", "--lines")

args = parser.parse_args()
nbytes = args.nbytes
if nbytes == None:
    nbytes = random.randint(32, 1024)


with open(args.filename, "w") as fout:
    for i in range(nbytes):
        fout.write(random.choice(chars_tot))
