const FixedPointMath = artifacts.require('FixedPointMathWrapper')

contract('Fixed point math', () => {
  let fixedPointMath
  //const base = 10**18
  const base = 1100000000000000000

  before(async () => {
    fixedPointMath = await FixedPointMath.new()
  })

  for (const exp of [17, 19, 31, 32, 33, 40]) {
    it('pow', async () => {
      const r1_1 = await fixedPointMath.powFixed(base, exp)
      const r1_2 = await fixedPointMath.powFixed.estimateGas(base, exp)
      console.log(`Result: ${r1_1.toNumber()}. Gas: ${r1_2}. For exp ${exp}`);
    })
  }

})
