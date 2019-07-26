# Simple Bonding Curve

A simple stateless contract to compute bonding curve sales and purchases used by Bancor Formula.

## Intro

This is motivated by [this issue](https://github.com/bancorprotocol/contracts/issues/287).

The main idea is that, in order to compute the exponentiation of fractional value `r`, instead of using logarithm to "bring it down" and then the exponential function, as the Bancor contract does, we do the actual math using a newly created fixed point math library.

See, for reference:
https://blog.relevant.community/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a
https://medium.com/@billyrennekamp/converting-between-bancor-and-bonding-curve-price-formulas-9c11309062f5

## N-th root

Of course the big challenge is to compute the nth-root, or fractionial exponent, which is the reason for that complex math `exp(log())` in Bancor contract.

One important assumption is that the fractional exponent is always going to be of the form `1 / (n+1)`, where `n` is the exponent of the chosen bonding curve (see references above for deep explanation). So while Bancor contract allows to compute any exponent of the form `w / 1e6`, we don't need that much precision, and, although using the same library that calculation could be done too, we can optimize for our less general assumption.

To calculate that nth root we use the [classical method based](https://en.wikipedia.org/wiki/Nth_root_algorithm) on Newton's method for finding zeroes of functions.

Another important assumption, derived from purchase formula for this family of curves, is that the base of that nth root computation will always be in the interval `[1,2]`, as it's coming from the term `(1 + p/b)^(1/n)` and `0 <= p <= b` always holds true.

## Fixed point library

We used [this](https://github.com/CementDAO/Fixidity) as an inspiration, but we ended up creating our own mainly for the following reasons:

- It uses 24 decimals (although it can be changed), and we wanted 18 (typical ERC20 tokens precision)
- It uses signed integers instead of `uint`
- Maybe some "not invented here syndrome"? ;-P

## TODO

- [ ] Clean
- [ ] Add more tests, specially for really large values
- [ ] Explore optimizations: closer initial value alternative nth root algorithms, ...
