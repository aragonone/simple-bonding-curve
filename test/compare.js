const fs = require('fs')
const path = require('path')

const Bancor = artifacts.require('BancorFormula')
const Simple = artifacts.require('SimpleBondingCurve')

const fileNameBase = 'bonding_curve_comparison'
const outputPathSale = path.join(__dirname, `${fileNameBase}_sale.csv`)
const outputPathPurchase = path.join(__dirname, `${fileNameBase}_purchase.csv`)

contract('Simple bonding curve', (accounts) => {
  let bancor, simple
  let outputStreamSale, outputStreamPurchase

  before(async() => {
    bancor = await Bancor.new()
    simple = await Simple.new()
    outputStreamSale = fs.createWriteStream(outputPathSale)
    outputStreamSale.write('supply(s), connectorBalance(b), 1/r, sellAmount(k), real, bancor, simple, bancor error, simple error, bancor error %, simple error %, bancor gas, simple gas, gas increase %\n')
    outputStreamPurchase = fs.createWriteStream(outputPathPurchase)
    outputStreamPurchase.write('supply(s), connectorBalance(b), 1/r, buyAmount(p), real, bancor, simple, bancor error, simple error, bancor error %, simple error %, bancor gas, simple gas, gas increase %\n')
  })

  const supplies = [ 1000 ]
  const connectorBalances = [ 100 ]
  const reverseReserveRatios = [ 1, 2, 3, 5, 10 ]
  const sellAmounts = [ 20, 200, 999 ]
  const buyAmounts = [ 2, 20, 99 ]

  const REVERT = 'revert!'

  const realPurchase = (supply, connectorBalance, reverseReserveRatio, buyAmount, log=false) => {
    const r = supply * ((1 + buyAmount / connectorBalance)**(1/reverseReserveRatio) - 1)
    if (log)
      console.log('real buy: ', supply, connectorBalance, reverseReserveRatio, buyAmount, r);
    return r
  }

  const realSale = (supply, connectorBalance, reverseReserveRatio, sellAmount, log=false) => {
    const r = connectorBalance * (1 - (1 - sellAmount / supply)**reverseReserveRatio)
    if (log)
      console.log('real sale: ', supply, connectorBalance, reverseReserveRatio, sellAmount, r);
    return r
  }

  const compareSale = async(supply, connectorBalance, reverseReserveRatio, sellAmount) => {
    let bancorResult
    let bancorGas
    try {
      bancorResult = (await bancor.calculateSaleReturn(supply, connectorBalance, 1e6 / reverseReserveRatio, sellAmount)).toNumber()
      bancorGas = await bancor.calculateSaleReturn.estimateGas(supply, connectorBalance, 1e6 / reverseReserveRatio, sellAmount)
    } catch (e) {
      bancorResult = REVERT
      bancorGas = '-'
    }

    let simpleResult
    let simpleGas
    try {
      simpleResult = (await simple.calculateSaleReturn2(supply, connectorBalance, reverseReserveRatio - 1, sellAmount)).toNumber()
      simpleGas = await simple.calculateSaleReturn2.estimateGas(supply, connectorBalance, reverseReserveRatio - 1, sellAmount)
    } catch (e) {
      simpleResult = REVERT
      simpleGas = '-'
    }

    const realResult = realSale(supply, connectorBalance, reverseReserveRatio, sellAmount)

    let computedLine, computedGasLine
    if (bancorResult == REVERT || simpleResult == REVERT) {
      computedLine = '-, -, -, -,'
      computedGasLine = '-'
    } else {
      computedLine = `${bancorResult - realResult}, ${simpleResult - realResult}, ` +
        `${(bancorResult - realResult) / realResult}, ${(simpleResult - realResult) / realResult}, `
      computedGasLine = `${(simpleGas - bancorGas) / bancorGas}`
    }
    const line = `${supply}, ${connectorBalance}, ${reverseReserveRatio}, ${sellAmount}, ${realResult}, ` +
          `${bancorResult}, ${simpleResult}, ` +
          computedLine +
          `${bancorGas}, ${simpleGas}, ` + computedGasLine
    outputStreamSale.write(line + '\n')
    //console.log('sale comparison', line)
  }

  const compareBuy = async(supply, connectorBalance, reverseReserveRatio, buyAmount) => {
    const bancorResult = await bancor.calculatePurchaseReturn(supply, connectorBalance, 1e6 / reverseReserveRatio, buyAmount)
    const bancorGas = await bancor.calculatePurchaseReturn.estimateGas(supply, connectorBalance, 1e6 / reverseReserveRatio, buyAmount)

    const simpleResult = await simple.calculatePurchaseReturn2(supply, connectorBalance, reverseReserveRatio - 1, buyAmount)
    const simpleGas = await simple.calculatePurchaseReturn2.estimateGas(supply, connectorBalance, reverseReserveRatio - 1, buyAmount)

    const realResult = realPurchase(supply, connectorBalance, reverseReserveRatio, buyAmount)

    const line = `${supply}, ${connectorBalance}, ${reverseReserveRatio}, ${buyAmount}, ${realResult}, ` +
          `${bancorResult.toNumber()}, ${simpleResult.toNumber()}, ` +
          `${bancorResult.toNumber() - realResult}, ${simpleResult.toNumber() - realResult}, ` +
          `${(bancorResult.toNumber() - realResult) / realResult}, ${(simpleResult.toNumber() - realResult) / realResult}, ` +
          `${bancorGas}, ${simpleGas}, ${(simpleGas - bancorGas) / bancorGas}`
    outputStreamPurchase.write(line + '\n')
    //console.log('purchase comparison', line)
  }

  const bancorSale = async(supply, connectorBalance, reverseReserveRatio, sellAmount) => {
    let bancorResult
    try {
      bancorResult = (await bancor.calculateSaleReturn(supply, connectorBalance, 1e6 / reverseReserveRatio, sellAmount)).toNumber()
    } catch (e) {
      bancorResult = REVERT
    }
    console.log('bancor sale:', supply, connectorBalance, reverseReserveRatio, sellAmount, bancorResult);
  }

  const simpleSale = async(supply, connectorBalance, reverseReserveRatio, sellAmount) => {
    const simpleResult = await simple.calculateSaleReturn2(supply, connectorBalance, reverseReserveRatio - 1, sellAmount)
    console.log('simple sale: ', supply, connectorBalance, reverseReserveRatio, sellAmount, simpleResult.toNumber());
  }

  const bancorBuy = async(supply, connectorBalance, reverseReserveRatio, buyAmount) => {
    const bancorResult = await bancor.calculatePurchaseReturn(supply, connectorBalance, 1e6 / reverseReserveRatio, buyAmount)
    console.log('bancor buy:', supply, connectorBalance, reverseReserveRatio, buyAmount, bancorResult.toNumber());
  }

  const simpleBuy = async(supply, connectorBalance, reverseReserveRatio, buyAmount) => {
    //console.log(await simple.rootFixed2("1200000000000000000", 2, 3, "1500000000000000000"));
    const simpleResult = await simple.calculatePurchaseReturn2(supply, connectorBalance, reverseReserveRatio - 1, buyAmount)
    console.log('simple buy: ', supply, connectorBalance, reverseReserveRatio, buyAmount, simpleResult.toNumber());
  }

  const nestedMaps = async(f) => {
    await Promise.all(supplies.map(
      supply => connectorBalances.map(
        connectorBalance => reverseReserveRatios.map(
          reverseReserveRatio => f(supply, connectorBalance, reverseReserveRatio)
        ).reduce((acc, val) => acc.concat(val), [])
      ).reduce((acc, val) => acc.concat(val), [])
    ).reduce((acc, val) => acc.concat(val), []))
  }

  const versions = [
    {
      name: "weis",
      preProcess: x => x
    },
    {
      name: "gweis",
      preProcess: x => x * 1e9
    },
    {
      name: "units",
      preProcess: x => web3.toWei(x)
    }
  ]
  for (const version of versions) {
    context.only(`Comparison of ${version.name}`, () => {
      it(`compares using ${version.name}`, async () => {
        const f = (supply, connectorBalance, reverseReserveRatio) => {
          //console.log(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio);
          const sPromises = sellAmounts.map(
            sellAmount => compareSale(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(sellAmount))
          )
          const bPromises = buyAmounts.map(
            buyAmount => compareBuy(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(buyAmount))
          )
          return sPromises.concat(bPromises)
        }

        await nestedMaps(f)
      })
    })

    context(`Sales of ${version.name}`, () => {
      it('Bancor sales', async () => {
        const f = (supply, connectorBalance, reverseReserveRatio) => {
          return sellAmounts.map(
            sellAmount => bancorSale(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(sellAmount))
          )
        }

        await nestedMaps(f)
      })

      it('Simple sales', async () => {
        const f = (supply, connectorBalance, reverseReserveRatio) => {
          return sellAmounts.map(
            sellAmount => simpleSale(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(sellAmount))
          )
        }

        await nestedMaps(f)
      })

      it('Real sales', async () => {
        const f = (supply, connectorBalance, reverseReserveRatio) => {
          return sellAmounts.map(
            sellAmount => realSale(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(sellAmount), true)
          )
        }

        await nestedMaps(f)
      })
    })

    context(`Purchases of ${version.name}`, () => {
      it('Bancor buys', async () => {
        const f = (supply, connectorBalance, reverseReserveRatio) => {
          return buyAmounts.map(
            buyAmount => bancorBuy(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(buyAmount))
          )
        }

        await nestedMaps(f)
      })

      it('Simple buys', async () => {
        const f = (supply, connectorBalance, reverseReserveRatio) => {
          return buyAmounts.map(
            buyAmount => simpleBuy(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(buyAmount))
          )
        }

        await nestedMaps(f)
      })

      it('Real buys', async () => {
        const f = (supply, connectorBalance, reverseReserveRatio) => {
          return buyAmounts.map(
            buyAmount => realPurchase(version.preProcess(supply), version.preProcess(connectorBalance), reverseReserveRatio, version.preProcess(buyAmount), true)
          )
        }

        await nestedMaps(f)
      })
    })
  }
})
