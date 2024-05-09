# Adder

ROHD HCL provides an adder module to get the sum from a list of logic. As of now, we have

- [Ripple Carry Adder](#ripple-carry-adder)

- [One's Complement Adder](#ones-complement-adder)


## Ripple Carry Adder

A ripple carry adder is a digital circuit used for binary addition. It consists of a series of full adders connected in a chain, with the carry output of each adder linked to the carry input of the next one. Starting from the least significant bit (LSB) to most significant bit (MSB), the adder sequentially adds corresponding bits of two binary numbers.

The [`RippleCarryAdder`](https://intel.github.io/rohd-hcl/rohd_hcl/RippleCarryAdder-class.html) module in ROHD-HCL accept input  `Logic`s a and b as the input pin and the name of the module `name`. Note that the width of the inputs must be the same or a `RohdHclException` will be thrown.

An example is shown below to add two inputs of signals that have 8-bits of width.

```dart
final a = Logic(name: 'a', width: 8);
final b = Logic(name: 'b', width: 8);

a.put(5);
b.put(5);

final rippleCarryAdder = RippleCarryAdder(a, b);
final sum = rippleCarryAdder.sum;
```

## One's Complement Adder

A one's complement adder is an adder that presumes inputs are in 1's
complement form where negation is simply inverting each bit (versus
two's complement form which adds '1' to the inverted one's complement
form). The advantage of one's complement is that there is no need to
perform carry operations for negation.

The [`Ones Complement Adder`] module in ROHD-HCL accepts numbers in
sign and magnitude form with a single bit `Logic` indicating sign and
a `Logic` for the magnitude for each operand 'a' and 'b'. The output
is in terms of sign and magnitude ('out'). Large additions can
overflow into the 'carry' output.

For a correct result, the larger magnitude number must be the first
operand 'a'. For efficiency, this requirement is not checked as it
requires a hardware comparator.

For subtraction, one can simply invert the sign of the 'b' operand.

Here is an example of use:

```dart
final aSign = Logic();
final a = Logic(name: 'a', width: 8)
final bSign = Logic();
final b = Logic(name: 'b', width: 8)

final onesComplementAdder = OnesComplementAdder(a, b);
final out = onesComplementAdder.out;
final sign = onesComplementAdder.sign;
```
Here is an example `FloatingPointAdder` schematic:
[FloatingPointAdder Schematic](https://intel.github.io/rohd-hcl/FloatingPointAdder.html)
