# Floating Point Operations

In ROHD-HCL we have introduced a variable sized floating point type
upon which we will have more and more floating point operation
components, such as addition, multiplication, etc. To properly support
floating point manipulation, especially IEEE floating point
operations, we support the concepts of NAN, subnormal representations,
etc.

So far, we have created one key floating point operation component:

- [Floating Point Adder](#floating-point-adder)


## Floating Point Values

ROHD-HCL supports a `FloatingPointValue` type which consists of a
parameterized exponent and mantissa width, along with helper functions
and literals to support the floating point value abstraction. These
values can be used in testing floating point components.

A `FloatingPointValue` value can be constructed using factory
operations as follows:

- Individual `LogicValue`s for the sign, exponent and magnitude for
the equivalent floating point value.
- A string representation of the sign, exponent, and magnitude
- From a `double` via a conversion operation (direct conversion if the
  exponent and mantissa widths match those of the native `double`
  type).

Here are examples of constructing `FloatingPointValue`s:

```dart
final fpvFromString = FloatingPointValue.ofString("0 1000001 010000100000");

final fpvFromStrings = FloatingPointValue.ofStrings("0", "1000001", "0100010000");

final pi = "3.14159";
final exponentWidth = 6;
final mantissaWidth = 12;
final fpvFromDouble = FloatingPointValue.fromDouble(pi, exponentWidth, mantissaWidth);

final fpvFromNative = FloatingPoint64Value.fromDouble(pi);
```

`FloatingPointValue`s can also be converted to string representations
as well as native `double` types.

Mathematical operations are supported on `FloatingPointValue`s, such
as addition, multiplication subtraction, division, and negation.

Several important IEEE-754 floating point standard literals are
supported which represent significant corner cases for
`FloatingPointValue`s. What is significant is these are analogs in
each floating point parameterization whereas the standard only defines
them for 32-bit, 64-bit, and extended-precisions formats.  Here they
are in increasing value:

- negativeInfinity: the smallest possible number representable in the type
- negativeZero: the value 0.0 with a negative sign
- positiveZero: the value 0.0 with a positive sign
- smallestPositiveSubnormal: the smallest magnitude number 
- largestPositiveSubnormal: the largest magnitude number not representatable with the smallest possible exponent
- smallestPositiveNormal: the smallest magnitude number with the smallest possible exponent
- largestLessThanOne: the largest number just below 1.0
- one: the value 1.0
- smallestLargerThanOne: the smallest number just above 1.0
- largestNormal: the largest number representable in the format
- infinity: a representation of infinity in the format

Each of these are available similar to the factory below:

```dart
final exponentWidth = 6;
final mantissaWidth = 12;
final smallestSubnormal = FloatingPointValue.getFloatingPointConstant(
    FloatingPointConstants.smallestPositiveSubnormal, 
    exponentWidth,
	mantissaWidth);
```

Finally, ROHD-HCL has a structure, `FloatingPoint` which inherits from
`LogicStructure` for representing floating point numbers in hardware,
storing `FloatingPointValue`.  This type is parameterized by exponent
width and mantissa width.

ROHD-HCL supports two critical variants: `FloatingPoint32` and
`FloatingPoint64`.

## Floating Point Adder

The `FloatingPointAdder` adds two numbers represented as
`FloatingPoint` structures. It is parameterized not only by the
exponent and mantissa widths, but also by the kind of `ParallelPrefix`
compute elements used in the internal mantissa adder and leading zero
detection.

Here is how we can add two `FloatingPoint` numbers.
```dart
final aValue = 4.5;
final bValue = 3.75;
final aFloatingPoint = FloatingPoint32()..put(FloatingPoint32Value.fromDouble(aValue));
final bFloatingPoint = FloatingPoint32()..put(FloatingPoint32Value.fromDouble(bValue));

final fpAdder = FloatingPointAdder(aFloatingPoint, bFloatingPoint, KoggeStone.new);

final fpSum = fpAdder.out;

print('Sum is ${fpSum.floatingPointValue.toDouble()}');
```
