var kakuna = require('./kakuna.js')

async function main() {
	if (process.argv.length < 4) {
	  throw new Error('proporcione el nombre del contrato compilado y el código de bytes del preludio como argumentos.')
	}

	const contractName = process.argv[2]
	const preludeRaw = process.argv[3]

	if (!(preludeRaw.slice(0, 2) === '0x')) {
	  throw new Error('Asegúrese de formatear el preludio como una cadena hexadecimal: `0xc0de... `')
	}
	let initCode
	let runtimeCode

	code = await kakuna.kakuna(contractName, preludeRaw, true)

	console.log('INIT CODE:', code[0])
	console.log()
	console.log('RUNTIME CODE:', code[1])
}

main()
