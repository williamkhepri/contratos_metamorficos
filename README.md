# Metamórfico

![GitHub](https://img.shields.io/github/license/0age/metamorphic.svg?colorB=brightgreen)
[![Build Status](https://travis-ci.org/0age/metamorphic.svg?branch=master)](https://travis-ci.org/0age/metamorphic)
[![standard-readme compliant](https://img.shields.io/badge/standard--readme-OK-green.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> Metamórfico: una fábrica de contratos para la creación de contratos metamórficos (es decir, reasignables).
> Este repositorio es una traducción del repositorio original creado por 0age [metamorphic](https://github.com/0age/metamorphic/)


Este [contrato de fábrica](https://github.com/williamkhepri/contratos_metamorficos/blob/main/contratos/metamorphic_contract_factory.sol) crea *contratos metamórficos* o contratos que se pueden volver a implementar con un nuevo código en la misma dirección. Lo hace implementando el contrato metamórfico con código de inicialización fijo y no determinista a través del código de operación CREATE2. Éste código de inicialización clona un contrato de implementación dado, y opcionalmente, lo inicializa en una operación. Una vez que un contrato sufre una metamorfosis, todo el almacenamiento existente se eliminará y cualquier código de contrato existente se reemplazará con el código de contrato implementado del nuevo contrato de implementación. Alternativamente, la fábica también puede crear contratos metamórficos que utilizan un constructor desplegándolos con un [contrato transitorio](https://github.com/williamkhepri/contratos_metamorficos/blob/main/contratos/transient_contract.sol) intermedio. De lo contrario, se puede utilizar un argumento para llamar atómicamente a una función de inicialización después de clonar una instancia.
También hay una [fábrica de create2 inmutable](https://github.com/williamkhepri/contratos_metamorficos/blob/main/contratos/inmutable_create2_factory.sol) que no ejecuta cambios de contrato, evitando así el metamorfismo de cualquier contrato que implemente(*aunque todavía pueden implementar sus propios metamórficos*).

Este repositorio también incluye [Metapod](https://github.com/williamkhepri/contratos_metamorficos/blob/main/contratos/metapod.sol), una fábrica para implementar contratos metamórficos "reforzados". (*Tenga en cuenta que la versión proporcionada de Metapod utiliza una dirección codificada, utilizada por el conjunto de pruebas local, a lo largo del contrato deberá modificarla para implementar en cualquier otra dirección*). Todos los contratos implementados a través de Metapod deben incluir un preludio(*o fragmento de código inicial*) que le permite destruir el contrato y reenviar todos los fondos a un contrato de vault dedicado. Para insertar el preludio en su contrato, primero debe modificar cualquier elemento de pila utilizado por destinos `JUMP` o `JUMPI`, así como por compensaciones por ´CODECOPY´. Para probar esto, hay una utidad provista llamada [Kakuna](#), una **POC propensa a errores** para analizar un contrato e insertar un preludio.

**DESCARGO DE RESPONSABILIDAD: esto implementa características/ errores altamente experimentales: asegúrese de implementar los controles apropiados en sus contratos metamórficos y *eduque a los usuarios de sus contratos* que interactuen con ellos. Estos contratos aún no se han probado o auditado completamente; proceda con precaución y comparta las vulnerabilidades u optimizaciones que descubra.**

Visite [esta publicación](http://www.williamkhepri.com/contratos-metamorficos-de-ethereum/) para entender el contexto.

Fábrica de Contratos Metamórficos en Mainnet: [0x00000000e82eb0431756271F0d00CFB143685e7B](https://etherscan.io/address/0x00000000e82eb0431756271f0d00cfb143685e7b)

Fábrica de Contratos Metamórficos en Ropsten: [0x00000000D63fB7385Ae38E7753F70e36d190abc2](https://ropsten.etherscan.io/address/0x00000000D63fB7385Ae38E7753F70e36d190abc2)

Fábrica de Create2 Inmutable en Mainnet: [0x000000000063b99B8036c31E91c64fC89bFf9ca7](https://etherscan.io/address/0x000000000063b99b8036c31e91c64fc89bff9ca7#code)

Fábrica de Create2 Inmutable en Ropsten: [0x000000B64Df4e600F23000dbAEEB8c0052C88e73](https://ropsten.etherscan.io/address/0x000000b64df4e600f23000dbaeeb8c0052c88e73)

Metapod en Mainnet: [0x00000000002B13cCcEC913420A21e4D11b2DCd3C](https://etherscan.io/address/0x00000000002b13cccec913420a21e4d11b2dcd3c)

Metapod en Ropsten: [0x0000000000f647BA29e4Dd009D2B7CADa21c1c68](https://ropsten.etherscan.io/address/0x0000000000f647ba29e4dd009d2b7cada21c1c68)


## Tabla de Contenidos

- [Instalación](#instalación)
- [Uso](#uso)
- [API](#api)
- [Mantenimiento](#Mantenimiento)
- [Licencia](#Licencia)

## Instalación
Para instlarlo localmente, necesitarás Node.js v10+ y Yarn *(o npm)*. Para tener todo configurado:
```sh
$ git clone https://github.com/williamkhepri/metamorphic.git
$ cd metamorphic
$ yarn install
$ yarn build
```

## Uso
En un nuevo terminal, inicia el testRPC, ejecuta los tests, y elimine testRPC *(puedes hacer todo esto a la vez mediante* `yarn all` *si lo prefieres)*:
```sh
$ yarn start
$ yarn test
$ yarn linter
$ yarn stop
```

Para usar Kakuna, primero crea los contratos, luego ejecuta lo siguiente, reemplazando el nombre del contrato y el preludio como desees (deberás obtener e insertar el preludio correcto para usar con Metapod):
```sh
$ yarn kakuna ContractOne 0x4150
```

## API

**Esta documentación es incompleta - consulta el código fuente de cada contrato para obtener un resumen mas completo.**

- [metamorphic_contract_factory.sol](#metamorphic_contract_factorysol)
- [inmutable_create2_factory.sol](#inmutable_create2_factorysol)

### [metamorphic_Contract_Factory.sol](https://github.com/williamkhepri/contratos_metamorficos/blob/main/contratos/metamorphic_contract_factory.sol)

Este contrato crea contratos metamórficos o contratos que se pueden volver a implementar con un nuevo código en la misma dirección. Lo hace mediante la implementación de un contrato con código de inicialización fijo, 
no determinista a través del código de operación `CREATE2`. Este contrato clona el contrato de implementación en su constructor. Una vez que un contrato sufre una metamorfosis, todo el almacenamiento existente se 
eliminará y cualquier código de contrato existente se reemplazará con el código de contrato implementado del nuevo contrato de implementación.

#### Eventos

```Solidity
event Metamorphosed(address metamorphicContract, address newImplementation);
```

#### Funciones

- [deployMetamorphicContract](#deploymetamorphiccontract)
- [deployMetamorphicContractFromExistingImplementation](#deploymetamorphiccontractfromexistingimplementation)
- [getImplementation](#getimplementation)
- [getImplementationContractAddress](#getimplementationcontractaddress)
- [findMetamorphicContractAddress](#findmetamorphiccontractaddress)
- [getMetamorphicContractInitializationCode](#getmetamorphiccontractinitializationcode)
- [getMetamorphicContractInitializationCodeHash](#getmetamorphiccontractinitializationcodehash)


#### deployMetamorphicContract

Implementa un contrato metamórfico enviando un salt o nonce dado junto con el código de inicialización para el contrato metamórfico y, opcionalmente, proporciona datos de llamada para inicializar el nuevo contrato metamórfico. Para reemplazar el contrato, primero autodestruiremos el contrato actual, luego llamaremos con el mismo valor de salt y el nuevo código de inicialización *(ten en cuenta que todo el estado existente se eliminará del contrato)*. También ten en cuenta que los primeros 20 bytes de la salt deben coincidir con la dirección de llamada, lo que evita que las partes no deseadas creen contratos.

```Solidity
function deployMetamorphicContract(
  bytes32 salt,
  bytes implementationContractInitializationCode,
  bytes metamorphicContractInitializationCalldata
) external payable returns (
  address metamorphicContractAddress
)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| salt | bytes32 | El nonce que se pasará a la llamada CREATE2 y, por lo tanto, determinará la dirección resultante del contrato metamórfico. | 
| implementationContractInitializationCode | bytes | El código de inicialización del contrato metamórfico.Se utilizará para implementar un nuevo contrato que luego el contrato metamórfico clonará en su constructor. | 
| metamorphicContractInitializationCalldata | bytes | Un parámetro de datos opcional que se puede utilizar para inicializar atómicamente el contrato metamórfico. | 

Devuelve: Dirección del contrato metamórfico que se creará.

#### deployMetamorphicContractFromExistingImplementation

Implementa un contrato metamórfico enviando un salt o nonce dado junto con la dirección de un contrato de implementación existente para clonar y, opcionalmente, proporciona datos de llamada para inicializar el nuevo contrato metamórfico.
Para reemplazar el contrato, primero autodestruye el contrato actual, luego llama con el mismo valor de salt y una nueva dirección de implementación *(ten en cuenta que todo el estado existente se eliminará del contrato existente)*. 
También ten en cuenta que los primeros 20 bytes de la salt deben coincidir con la dirección de llamada, lo que evita que las partes no deseadas creen contratos.

```Solidity
function deployMetamorphicContractFromExistingImplementation(
  bytes32 salt,
  address implementationContract,
  bytes metamorphicContractInitializationCalldata
) external payable returns (
  address metamorphicContractAddress
)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| salt | bytes32 | El nonce que se pasará a la llamada a CREATE2 y, por lo tanto, determinará la dirección resultante del contrato metamórfico. | 
| implementationContract | address | La dirección del contrato de implementación existente para clonar. | 
| metamorphicContractInitializationCalldata | bytes | Un parámetro de datos opcional que se puede utilizar para inicializar atómicamente el contrato metamórfico. | 

Devuelve: Dirección del contrato metamórfico que se creará.

#### getImplementation

Función Ver para recuperar la dirección del contrato de implementación para clonar. Llamado por el constructor de cada contrato metamórfico.

```Solidity
function getImplementation() external view returns (address implementation)
```

#### getImplementationContractAddress

Función "Ver" para recuperar la dirección del contrato de implementación actual de un contato metamórfico dado, donde la dirección del contrato se proporciona como argumento.
Ten en cuenta que el contrato de implementación tiene un estado independiente y puede haber sido alterado o autodestruido desde la última vez que fue clonado por el contrato metamórfico.

```Solidity
function getImplementationContractAddress(
  address metamorphicContractAddress
) external view returns (
  address implementationContractAddress
)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| metamorphicContractAddress | address | La dirección del contrato metamórfico. | 

Devuelve: Dirección del correspondiente contrato de ejecución.

#### findMetamorphicContractAddress

Calcula la dirección del contrato metamórfico que se creará al enviar una salt determinada al contrato.

```Solidity
function findMetamorphicContractAddress(
  bytes32 salt
) external view returns (
  address metamorphicContractAddress
)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| salt | bytes32 | El nonce pasado a CREATE2 por el contrato metamórfico. | 

Devuelve: La dirección del contrato metamórfico correspondiente.

#### getMetamorphicContractInitializationCode

Función Ver para recuperar el código de inicialización de contratos metamórficos con fines de verificación.

```Solidity
function getMetamorphicContractInitializationCode() external view returns (
  bytes metamorphicContractInitializationCode
)
```

#### getMetamorphicContractInitializationCodeHash

Función Ver para recuperar el hash keccak256 del código de inicialización de contratos metamórficos con fines de verificación.

```Solidity
function getMetamorphicContractInitializationCodeHash() external view returns (
  bytes32 metamorphicContractInitializationCodeHash
)
```

### [inmutable_create2_factory.sol](https://github.com/williamkhepri/contratos_metamorficos/blob/main/contratos/inmutable_create2_factory.sol)

Este contrato proporciona una función safeCreate2 que toma un valor de salt y un bloque de código de inicialización como argumentos y los pasa al ensamblaje en línea. 
El contrato evita los redespliegues al mantener un mapeo de todos los contratos que ya se han implementado, y previene los adelantos u otras colisiones al requerir que los primeros 20 bytes de la salt sean iguales a la dirección de la persona que llama
*(esto se puede omitir configurando los primeros 20 bytes como una dirección nula)*.
También hay una función de vista que calcula la dirección del contrato que se creará al enviar una salt o nonce dado junto con un bloque dado de código de inicialización.

#### Funciones

- [safeCreate2](#safecreate2)
- [findCreate2Address](#findcreate2address)
- [findCreate2AddressViaHash](#findcreate2addressviahash)
- [hasBeenDeployed](#hasbeendeployed)

#### safeCreate2

Crea un contrato usando `CREATE2` enviando un salt o nonce dado junto con el código de inicialización del contrato. Ten en cuenta que los primeros 20 bytes del salt deben coincidir con los de la dirección de llamada, lo que evita que terceros no deseados envíen eventos de creación de contrato.

```Solidity
function safeCreate2(
  bytes32 salt,
  bytes initializationCode
) external payable returns (
  address deploymentAddress
)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| salt | bytes32 | El nonce que se pasará a la llamada a CREATE2. | 
| initializationCode | bytes | El código de inicialización que se pasará a la llamada a CREATE2. | 

Devuelve: Dirección del contrato que se creará, o la dirección nula si ya existe un contrato en esa dirección.

#### findCreate2Address

Calcula la dirección del contrato que se creará al enviar un salt o nonce determinado al contrato junto con el código de inicialización del contrato. La dirección "CREATE2" se calcula de acuerdo con EIP-1014, y se adhiere a la fórmula de "keccak256 (0xff ++ dirección ++ salt ++ keccak256(init_code)))[12:]" cuando se realiza el cálculo. Luego, la dirección calculada se verifica en busca de cualquier código de contrato existente; de ser así, se devolverá la dirección nula.

```Solidity
function findCreate2Address(
  bytes32 salt,
  bytes initCode
) external view returns (
  address deploymentAddress
)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| salt | bytes32 | El nonce pasó al cálculo de la dirección CREATE2. | 
| initCode | bytes | El código de inicialización del contrato que se utilizará y que se pasará al cálculo de la dirección CREATE2. | 

Devuelve: Dirección del contrato que se creará, o la dirección nula si ya se ha desplegado un contrato en esa dirección.

#### findCreate2AddressViaHash

Calcula la dirección del contrato que se creará al enviar un salt o nonce determinado al contrato junto con el hash keccak256 del código de inicialización del contrato. La dirección "CREATE2" se calcula de acuerdo con EIP-1014, y se adhiere a la fórmula de "keccak256(0xff ++ dirección ++ salt ++ keccak256(init_code)))[12:]" cuando se realiza el cálculo. Luego, la dirección calculada se verifica en busca de cualquier código de contrato existente; de ser así, se devolverá la dirección nula.

```Solidity
function findCreate2AddressViaHash(
  bytes32 salt,
  bytes32 initCodeHash
) external view returns (
  address deploymentAddress
)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| salt | bytes32 | El nonce pasó al cálculo de la direción CREATE2. | 
| initCodeHash | bytes32 | El hash keccak256 del código de inicialización que se pasará al cálculo de la dirección CREATE2. | 

Devuelve: Dirección del contrato que se creará, o la dirección nula si ya se ha desplegado un contrato en esa dirección.

#### hasBeenDeployed

Determina si la fábrica ya ha implementado un contrato en una dirección determinada.

```Solidity
function hasBeenDeployed(address deploymentAddress) external view returns (bool)
```

Argumentos:

| Nombre        | Tipo         | Descripción  |
| ------------- |------------- | -----|
| deploymentAddress | address | La dirección del contrato para comprobar. | 

Devuelve: True si el contrato se ha implementado, False en caso contrario.

## Mantenimiento

Traducción de [@williamkhepri](https://github.com/williamkhepri)
del repositorio original en inglés de [0age](https://github.com/0age) 

## Licencia

MIT © 2022 William Khepri
