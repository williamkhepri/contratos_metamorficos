# Metamórfico

![GitHub](https://img.shields.io/github/license/0age/metamorphic.svg?colorB=brightgreen)
[![Build Status](https://travis-ci.org/0age/metamorphic.svg?branch=master)](https://travis-ci.org/0age/metamorphic)
[![standard-readme compliant](https://img.shields.io/badge/standard--readme-OK-green.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

> Metamórfico: una fábrica de contratos para la creación de contratos metamórficos (es decir, reasignables).

Este [contrato de fábrica](https://github.com/williamkhepri/contratos_metamorficos/blob/main/metamorphic_contract_factory.sol) crea *contratos metamórficos* o contratos que se pueden volver a implementar con un nuevo código en la misma dirección. Lo hace implementando el contrato metamórfico con código de inicialización fijo y no determinista a través del código de operación CREATE2. Éste código de inicialización clona un contrato de implementación dado, y opcionalmente, lo inicializa en una operación. Una vez que un contrato sufre una metamorfosis, todo el almacenamiento existente se eliminará y cualquier código de contrato existente se reemplazará con el código de contrato implementado del nuevo contrato de implementación. Alternativamente, la fábica también puede crear contratos metamórficos que utilizan un constructor desplegándolos con un [contrato transitorio](#) intermedio. De lo contrario, se puede utilizar un argumento para llamar atómicamente a una función de inicialización después de clonar una instancia.
También hay una [fábrica de create2 inmutable](https://github.com/williamkhepri/contratos_metamorficos/blob/main/inmutable_create2_factory.sol) que no ejecuta cambios de contrato, evitando así el metamorfismo de cualquier contrato que implemente(*aunque todavía pueden implementar sus propios metamórficos*).

Este repositorio también incluye [Metapod](https://github.com/williamkhepri/contratos_metamorficos/blob/main/metapod.sol), una fábrica para implementar contratos metamórficos "reforzados". (*Tenga en cuenta que la versión proporcionada de Metapod utiliza una dirección codificada, utilizada por el conjunto de pruebas local, a lo largo del contrato deberá modificarla para implementar en cualquier otra dirección*). Todos los contratos implementados a través de Metapod deben incluir un preludio(*o fragmento de código inicial*) que le permite destruir el contrato y reenviar todos los fondos a un contrato de vault dedicado. Para insertar el preludio en su contrato, primero debe modificar cualquier elemento de pila utilizado por destinos `JUMP` o `JUMPI`, así como por compensaciones por ´CODECOPY´. Para probar esto, hay una utidad provista llamada [Kakuna](#), una **POC propensa a errores** para analizar un contrato e insertar un preludio.

**DESCARGO DE RESPONSABILIDAD: esto implementa características/ errores altamente experimentales: asegúrese de implementar los controles apropiados en sus contratos metamórficos y *eduque a los usuarios de sus contratos* que interactuen con ellos. Estos contratos aún no se han probado o auditado completamente; proceda con precaución y comparta las vulnerabilidades u optimizaciones que descubra.**

Visite [esta publicación](http://www.williamkhepri.com/contratos-metamorficos-de-ethereum/) para entender el contexto.

Fábrica de Contratos Metamórficos en Mainnet: [0x00000000e82eb0431756271F0d00CFB143685e7B](https://etherscan.io/address/0x00000000e82eb0431756271f0d00cfb143685e7b)

Fábrica de Contratos Metamórficos en Ropsten: [0x00000000D63fB7385Ae38E7753F70e36d190abc2](https://ropsten.etherscan.io/address/0x00000000D63fB7385Ae38E7753F70e36d190abc2)

Fábrica de Create2 Inmutable en Mainnet: [0x000000000063b99B8036c31E91c64fC89bFf9ca7](https://etherscan.io/address/0x000000000063b99b8036c31e91c64fc89bff9ca7#code)

Fábrica de Create2 Inmutable en Ropsten: [0x000000B64Df4e600F23000dbAEEB8c0052C88e73](https://ropsten.etherscan.io/address/0x000000b64df4e600f23000dbaeeb8c0052c88e73)

Metapod en Mainnet: [0x00000000002B13cCcEC913420A21e4D11b2DCd3C](https://etherscan.io/address/0x00000000002b13cccec913420a21e4d11b2dcd3c)

Metapod en Ropsten: [0x0000000000f647BA29e4Dd009D2B7CADa21c1c68](https://ropsten.etherscan.io/address/0x0000000000f647ba29e4dd009d2b7cada21c1c68)
