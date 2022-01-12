pragma solidity 0.5.6;

/*
@título: Fábrica de contratos metamórficos
@author: William Khepri
@notice: 
Este código crea un contratos metamórficos, o contratos que pueden ser redistribuidos con un nuevo código a la misma dirección.
Lo hace desplegando un contrato con código de inicialización fijo, no determinista a través del código de operación CREATE2.
Este contrato clona el contrato de implementación en su constructor.
Una vez que un contrato sufre una metamorfosis, se eliminará todo el almacenamiento existente y cualquier código de contrato existente
será reemplazado por el código del contrato implementado en la ejecución.
@dev CREATE2 no estará disponible en mainnet hasta (al menos) el bloque 7.280.000.
Este contrato aún no ha sido completamente probado o auditado - proceda con precaución y comparta
cualquier vulnerabilidad y optimización que descubra.
*/

contract MetamorphicContractFactory {
    //se activa cuando se implementa un contrato metamórfico al clonar otro contrato.
    event Metamorphosed(address metamorphicContract, address newImplementation);

    //se activa cuando se implementa un contrato metamórfico a través de un contrato transitorio.
    event MetamorphosedWithConstructor(
        address metamorphicContract, 
        address transientContract
    );

    //almacena el código de inicialización para contratos metamórficos.
    bytes private _metamorphicContractInitializationCode;

    //almacena el hash del código de inicialización para contratos metamórficos.
    bytes32 private _metamorphicContractInitializationCodeHash;

    //almacena el código de inicio para contratos transitorios que implementan contratos metamórficos.
    bytes private _transientContractInitializationCode;

    //también almacena el hash del código de inicialización para contratos transitorios.
    bytes32 private _transientContractInitializationCodeHash;


    //mantener un mapeo de contratos transitorios a códigos de inicio metamórficos.
    mapping(address => address) private _implementations;

    //mantener un mapeo de contratos transitorios a códigos de inicio metamórficos.
    mapping(address => bytes) private _initCodes;

    /**
    * @dev En el constructor, configura el código de incialización para contratos metamórficos
    así como el hash keccak256 del código de incialización dado.
    @param transientContractInitializationCode bytes El código de inicialización que se utilizará
    para implementar cualquier contrato transitorio, que implementará cualquier contrato 
    metamórfico que requiera el uso de un contructor.

    Código de inicialización del contrato metamórfico (29 bytes):

    0x5860208158601c335a63aaf10f428752fa158151803b80938091923cf3
* Description:
   *
   * pc|op|name         | [stack]                                | <memory>
   *
   * ** establecer el primer elemento de la pila en cero; se usará mas tarde **
   * 00 58 getpc          [0]                                       <>
   *
   * ** establecer el segundo elemento de la pila en 32, la logitud de la palabra devuelta por llamada estática **
   * 01 60 push1
   * 02 20 outsize        [0, 32]                                   <>
   *
   * ** establecer el tercer elemento de la pila en 0, posición de la palabra devuelta desde llamada estática **
   * 03 81 dup2           [0, 32, 0]                                <>
   *
   * ** establecer el cuarto elemento de la pila en 4, la logitud del selector de asigna a llamada estática **
   * 04 58 getpc          [0, 32, 0, 4]                             <>
   *
   * ** establecer el quinto lemento de la pila en 28, posición del selector dado a llamada estática **
   * 05 60 push1
   * 06 1c inpos          [0, 32, 0, 4, 28]                         <>
   *
   * ** establecer el sexto elemento de la pila en msg.sender, dirección de destino para llamada estática **
   * 07 33 caller         [0, 32, 0, 4, 28, caller]                 <>
   *
   * ** establecer el séptimo elemento de la pila en msg.gas, gas para reenviar una llamada estática**
   * 08 5a gas            [0, 32, 0, 4, 28, caller, gas]            <>
   *
   * ** establecer el octavo elemento de la pila en selector, "qué" almacenar a través de mstore **
   * 09 63 push4
   * 10 aaf10f42 selector [0, 32, 0, 4, 28, caller, gas, 0xaaf10f42]    <>
   *
   * ** establecer el noveno elemento de la pila en 0, "dónde" almacenar a través de mstore ***
   * 11 87 dup8           [0, 32, 0, 4, 28, caller, gas, 0xaaf10f42, 0] <>
   *
   * ** llamar a mstore, consumir 8 y 9 de la pila, colocar el selector en la memoria **
   * 12 52 mstore         [0, 32, 0, 4, 0, caller, gas]             <0xaaf10f42>
   *
   * ** llamar a staticcall, consumir elementos 2 a 7, colocar la dirección en la memoria **
   * 13 fa staticcall     [0, 1 (if successful)]                    <address>
   *
   * ** Voltear el bit de éxito en el segundo elemento de la pila para establecerlo a 0 **
   * 14 15 iszero         [0, 0]                                    <address>
   *
   * ** push un tercer 0 a la pila, posicion de la dirección en la memoria **
   * 15 81 dup2           [0, 0, 0]                                 <address>
   *
   * ** colocar la dirección de la posición en la memoria en el tercer elemento de la pila **
   * 16 51 mload          [0, 0, address]                           <>
   *
   * ** colocar la dirección en el cuarto elemento de la pila para que extcodesize la consuma **
   * 17 80 dup1           [0, 0, address, address]                  <>
   *
   * ** obtener extcodesize en el cuarto elemento de la pila para extcodecopy **
   * 18 3b extcodesize    [0, 0, address, size]                     <>
   *
   * ** tamaño dup y swap para usar mediante retorno al final del código de inicio **
   * 19 80 dup1           [0, 0, address, size, size]               <> 
   * 20 93 swap4          [size, 0, address, size, 0]               <>
   *
   * ** push a la posición del código 0 para apilar y reordenar los elementos de la pila para extcodecopy **
   * 21 80 dup1           [size, 0, address, size, 0, 0]            <>
   * 22 91 swap2          [size, 0, address, 0, 0, size]            <>
   * 23 92 swap3          [size, 0, size, 0, 0, address]            <>
   *
   * ** llamada a extcodecopy, consumir cuatro elementos, clonar el código de tiempo de ejecución en la memeoria **
   * 24 3c extcodecopy    [size, 0]                                 <code>
   *
   * ** devolver para implementar el código final en la memoria **
   * 25 f3 return         []                                        *Implementado!*
   *
   *
   * Código de inicialización de contrato transitorio derivado de TransientContract.sol.
   */
constructor ( bytes memory transientContractInitializationCode) public {
    //asigna el código de inicialización para el contrato metamórfico.
    _metamorphicContractInitializationCode = (
        hex"5860208158601c335a63aaf10f428752fa158151803b80938091923cf3"
    );

    //calcula y asigna el hash keccak256 del código de inicialización metamórfico.
    _metamorphicContractInitializationCodeHash = keccak256 (
        abi.encodePacked(
            _metamorphicContractInitializationCode
        )
    );

    //almacena el código de inicialización para el contrato transitorio.
    _transientContractInitializationCode = transientContractInitializationCode;

    //calcula y asigna el hash keccak256 del código de inicialización transitorio.
    _transientContractInitializationCodeHash = keccak256(
        abi.encodePacked(
            _transientContractInitializationCode
        )
    );
}
/* solhint-deshabilitar función-max-lines */
/**
*@dev Implementa un contrato metamórfico enviando un salt o nonce determinado junto con el código
de inicialización para el contrato metamórfico, y opcionalmente, proporcione datos de llamada para
inicializar el nuevo contrato metamórfico.
Para reemplazar el contrato, primero autodestruya el contrato actual luego llame con el mismo valor
de sal y un nuevo código de inicialización (tenga en cuenta que todos los estados existentes ser eliminarán
del contrato existente). También tenga en cuenta que los primero 20 bytes de la sal deben coincidir con la dirección
de llamada, que evita que los contratos sean creados por partes no deseadas.
@param salt bytes32 El nonce que se pasará a la llamada CREATE2 y así  determinará la dirección resultante del contrato
metamórfico.
@param implementationContractInitializationCode  bytes La inicialización del código de contrato de ejecución del contrato
metamórfico. Va a ser utilizado para implementar un nuevo contrato que luego el contrato metamórfico clonará en un su constructor.
@param metamorphicContractInitializationCalldata bytes Un dato opcional o parámetro que se utiliza para inicializar atómicamente el
contrato metamórfico.
@return Dirección del contrato metamórfico que se creará.
*/
function deployMetamorphicContract (
    bytes32 salt, 
    bytes calldata implementationContractInitializationCode, 
    bytes calldata metamorphicContractInitializationCalldata
) external payable containsCaller(salt) returns (
    address metamorphicContractAddress
){
    //mover el código de inicio de implementación y los datos de llamada de inicialización a la memoria
    bytes memory implInitCode = implementationContractInitializationCode;
    bytes memory data = metamorphicContractInitializationCalldata;

    //mover el código de inicialización del almacenamiento a la memoria
    bytes memory initCode = _metamorphicContractInitializationCode;

    //declarar variable para verificar que el contrato metamórfico se despliega correctamente
    address deployedMetamorphicContract;

    //determinar la dirección del contrato metamórfico.
    metamorphicContractAddress = _getMetamorphicContractAddress(salt);

    //declarar una variable para la dirección del contrato de implementación
    address implementationContract;

    //cargar el código de inicio de implementación y la longitud, luego implementar mediante CREATE
    /* solhint-disable no-inline-assembly */
    assembly {
        let encoded_data := add(0x20, implInitCode) //cargar código de inicialización
        let encoded_size := mload(implInitCode) //cargar logitud de código de inicialización
        implementationContract := create(       //llamada a CREATE con 3 argumentos.
        0,                                      //no reenviamos ninguna dotación.
        encoded_data,                           //pasamos el código de inicialización.
        encoded_size                            //pasamos la logitud del código de inicio
        )
    } /* solhint-enable no-inline-assembly */

    require(
        implementationContract != address(0), 
        "No se pudo implementar."
    );

    //almacena la implementación que será recuperada por el contrato metamórfico.
    _implementations[metamorphicContractAddress] = implementationContract;

    //cargar datos de contratos metamórficos y la logitud de los datos y desplegarlos a través de CREATE2.
    /* solhint-disable no-inline-assembly */
    assembly {
        let encoded_data := add(0x20, initCode) //cargar el código de inicialización
        let encoded_size := mload(initCode)     // carga la longitud del código de inicio.
        deployedMetamorphicContract := create2( //Llamada a CREATE2 con 4 argumentos.
            0,                                  // no reenviar ninguna dotación.
            encoded_data,                       //pasar el código de inicialización.
            encoded_size,                       //pasar la logitud del código de inicio.
            salt                                //pasar el valor de la sal.
        )
    } /* solhint-enable no-inline-assembly */

    //asegurarse de que los contratos se hayan implementado correctamente.
    require(
        deployedMetamorphicContract == metamorphicContractAddress, 
        "No se pudo implementar el nuevo contrato metamórfico."
    );

    //inicializar el nuevo contrato metamórfico si se proporciona algún dato o valor.
    if (data.length > 0 || msg.value > 0) {
        /* solhint-disable avoid-call-value */
        (bool success,) = deployedMetamorphicContract.call.value(msg.value)(data);
        /* solhint-enable avoid-call-value */

        require(success, "Fallo al inicializar el nuevo contrato metamórfico.");
    }
    emit Metamorphosed(deployedMetamorphicContract, implementationContract);
} /* solhint-enable function-max-lines */

  /**
   * @dev Implementa un contrato metamórfico enviando un salt o nonce determinado
   * junto con la dirección de un contrato de implementación existente para clonar, y 
   * Opcionalmente, proporcione datos de llamada para inicializar el nuevo contrato metamórfico.
   * Para reemplazar el contrato, primero autodestruya el contrato actual, luego llame
   * con el mismo valor de sal y una nueva dirección de implementación (tenga en cuenta que
   * todo el estado existente se eliminará del contrato existente). También tenga en cuenta
   * que los primeros 20 bytes de la sal deben coincidir con la dirección de llamada, que 
   * evita que los contratos sean creados por partes no deseadas.
   * @param salt bytes32 El nonce que se pasará a la llamada CREATE2 y
   * así determinará la dirección resultante del contrato metamórfico.
   * @param implementationContract address La dirección del contrato existente de implementación
   * para clonar.
   * @param metamorphicContractInitializationCalldata bytes Un dato opcional
   * parámetro que se puede utilizar para inicializar atómicamente el contrato metamórfico.
   * @return Dirección del contrato metamórfico que se creará.
   */
  function deployMetamorphicContractFromExistingImplementation(
    bytes32 salt,
    address implementationContract,
    bytes calldata metamorphicContractInitializationCalldata
  ) external payable containsCaller(salt) returns (
    address metamorphicContractAddress
  ) {
    // mueve los datos de llamada de inicialización a la memoria.
    bytes memory data = metamorphicContractInitializationCalldata;

    // mueve el código de inicialización del almacenamiento a la memoria.
    bytes memory initCode = _metamorphicContractInitializationCode;

    // declarar variable para verificar la implementación existosa del contrato metamórfico.
    address deployedMetamorphicContract;

    // determina la dirección del contrato metamórfico.
    metamorphicContractAddress = _getMetamorphicContractAddress(salt);

    // almacena la implementación que será recuperada por el contrato metamórfico.
    _implementations[metamorphicContractAddress] = implementationContract;

    // usando ensamblado en línea: cargue los datos y la longitud de los datos, luego llame a CREATE2.
    /* solhint-disable no-inline-assembly */
    assembly {
      let encoded_data := add(0x20, initCode) // cargar el código de inicialización.
      let encoded_size := mload(initCode)     // carga la logirud del código de inicio.
      deployedMetamorphicContract := create2( // llamada a CREATE2 con 4 argumentos.
        0,                                    // no reenviar ninguna dotación.
        encoded_data,                         // pasar el código de inicialización.
        encoded_size,                         // pasar la logitud del código de inicio.
        salt                                  // pasar el valor de la sal.
      )
    } /* solhint-enable no-inline-assembly */

    // asegurarse de que los contratos se hayan implementado correctamente.
    require(
      deployedMetamorphicContract == metamorphicContractAddress,
      "No se pudo implementar el nuevo contrato metamórfico."
    );

    // inicializar el nuevo contrato metamórfico si se proporciona algún dato o valor.
    if (data.length > 0 || msg.value > 0) {
      /* solhint-disable avoid-call-value */
      (bool success,) = metamorphicContractAddress.call.value(msg.value)(data);
      /* solhint-enable avoid-call-value */

      require(success, "No se pudo inicializar el nuevo contrato metamórfico.");
    }

    emit Metamorphosed(deployedMetamorphicContract, implementationContract);
  }

  /* solhint-disable function-max-lines */
  /**
   * @dev Implementa un contrato metamórfico enviando un salt o nonce determinado
   * junto con el código de inicialización a un contrato transitorio que luego
   * implementará el contrato metamórfico antes de autodestruirse inmediatamente. Al
   * reemplazar el contrato metamórfico, primero autodestruir el contrato actual, 
   * luego llame con el mismo valor de sal y un nuevo código de inicialización (tenga en cuenta
   * que todo el estado existente será eliminado del contrato existente). también
   * tenga en cuenta que los primeros 20 bytes de la sal deben coincidir con la dirección de llamada,
   * que evita que los contratos sean creados por partes no deseadas.
   * @param salt bytes32 El nonce que se pasará a la llamada CREATE2 y 
   * así determinará la dirección resultante del contrato metamórfico.
   * @param initializationCode bytes El código de inicialización para el contrato
   * metamórfico que será implementado por el contrato transitorio.
   * @return Dirección del contrato metamórfico que se creará.
   */
  function deployMetamorphicContractWithConstructor(
    bytes32 salt,
    bytes calldata initializationCode
  ) external payable containsCaller(salt) returns (
    address metamorphicContractAddress
  ) {
    // mover el código de inicialización del contrato transitorio del almacenamiento a la memoria.
    bytes memory initCode = _transientContractInitializationCode;

    // declarar variable para verificar la implementación existosa del contrato transitorio.
    address deployedTransientContract;

    // determina la dirección del contrato transitorio.
    address transientContractAddress = _getTransientContractAddress(salt);

    // almacena el código de inicialización que será recuperado por el contrato transitorio.
    _initCodes[transientContractAddress] = initializationCode;

    // cargar datos de contrato transitorio y la longitud de los datos, luego implementar a través de CREATE2.
    /* solhint-disable no-inline-assembly */
    assembly {
      let encoded_data := add(0x20, initCode) // cargar el código de incialización.
      let encoded_size := mload(initCode)     // cargar la longitud del código de inicio.
      deployedTransientContract := create2(   // llamada a create2 con 4 argumentos.
        callvalue,                            // reenviar cualquier dotación proporcionada.
        encoded_data,                         // pasar el código de inicialización.
        encoded_size,                         // pasar la logitud del código de inicio.
        salt                                  // pasar el valor de la sal.
      )
    } /* solhint-enable no-inline-assembly */

    // ensure that the contracts were successfully deployed.
    //asegurarse de que los contratos se hayan implementado correctamente.
    require(
      deployedTransientContract == transientContractAddress,
      "No se pudo implementar el contrato metamórfico usando el código de inicio y salt dado."
    );

    metamorphicContractAddress = _getMetamorphicContractAddressWithConstructor(
      transientContractAddress
    );

    emit MetamorphosedWithConstructor(
      metamorphicContractAddress,
      transientContractAddress
    );
  } /* solhint-enable function-max-lines */

  /**
   * @dev Ver función para recuperar la dirección de la implementación
   * contrato para clonar. Llamado por el constructor de cada contrato metamórfico.
   */
  function getImplementation() external view returns (address implementation) {
    return _implementations[msg.sender];
  }

  /**
   * @dev Ver función para recuperar el código de inicialización para un determinado
   * contrato metamórfico para desplegar a través de un contrato transitorio. Llamado por el
   * constructor de cada contrato transitorio.
   * @return El código de inicialización que se utilizará para implementar el contrato metamórfico.
   */
  function getInitializationCode() external view returns (
    bytes memory initializationCode
  ) {
    return _initCodes[msg.sender];
  }

  /**
   * @dev Ver función para recuperar la dirección de la implementación actual
   * contrato de un contrato metamórfico dado, donde la dirección del contrato 
   * se proporciona como argumento. Tenga en cuenta que el contrato de implementación
   * fue clonado por última vez por el contrato metamórfico.
   * @param metamorphicContractAddress address La dirección del contrato metamórfico.
   * @return Dirección del correspondiente contrato de ejecución.
   */
  function getImplementationContractAddress(
    address metamorphicContractAddress
  ) external view returns (address implementationContractAddress) {
    return _implementations[metamorphicContractAddress];
  }

  /**
   * @dev Ver función para recuperar el código de inicialiación para una determinada
   * instancia de contrato metamórfico implementado a través de un contrato transitorio, donde la dirección
   * del contrato transitorio se proporciona como argumento.
   * @return El código de inicialización utilizado para implementar el contrato metamórfico.
   */
  function getMetamorphicContractInstanceInitializationCode(
    address transientContractAddress
  ) external view returns (bytes memory initializationCode) {
    return _initCodes[transientContractAddress];
  }

  /**
   * @dev Calcula la dirección del contrato metamórfico que se creará
   * al someter una salt determinada al contrato.
   * @param salt bytes32 El nonce pasó a CREATE2 por contrato metamórfico.
   * @return Dirección del correspondiente contrato metamórfico.
   */
  function findMetamorphicContractAddress(
    bytes32 salt
  ) external view returns (address metamorphicContractAddress) {
    //determina la dirección donde se implementará el contrato metamórfico.
    metamorphicContractAddress = _getMetamorphicContractAddress(salt);
  }

  /**
   * @dev Calcula la dirección del contrato transitorio que se creará
   * al someter una salt determinada al contrato.
   * @param salt bytes32 El nonce pasó a CREATE2 al implementar el
   * contrato transitorio.
   * @return Dirección del correspondiente contrato transitorio.
   */
  function findTransientContractAddress(
    bytes32 salt
  ) external view returns (address transientContractAddress) {
    // determina la dirección donde se implementará el contrato transitorio.
    transientContractAddress = _getTransientContractAddress(salt);
  }

  /**
   * @dev Calcula la dirección del contrato metamórfico que se creará
   * por el contrato transitorio al someter una salt determinada al contrato.
   * @param salt bytes32 El nonce pasó a CREATE2 al implementar el
   * contrato transitorio.
   * @return Dirección del correspondiente contrato metamórfico.
   */
  function findMetamorphicContractAddressWithConstructor(
    bytes32 salt
  ) external view returns (address metamorphicContractAddress) {
    // determina la dirección del contrato metamórfico.
    metamorphicContractAddress = _getMetamorphicContractAddressWithConstructor(
      _getTransientContractAddress(salt)
    );
  }

  /**
   * @dev Función Ver para recuperar el código de inicialización de los contratos metamórficos
   * a efectos de verificación.
   */
  function getMetamorphicContractInitializationCode() external view returns (
    bytes memory metamorphicContractInitializationCode
  ) {
    return _metamorphicContractInitializationCode;
  }

  /**
   * @dev Función Ver para recuperar el hash keccak256 del código de inicialización de contratos metamórficos
   * a efectos de verificación.
   */
  function getMetamorphicContractInitializationCodeHash() external view returns (
    bytes32 metamorphicContractInitializationCodeHash
  ) {
    return _metamorphicContractInitializationCodeHash;
  }

  /**
   * @dev Función Ver para recuperar el código de inicialización de los contratos
   * transitorios a efectos de verificación.
   */
  function getTransientContractInitializationCode() external view returns (
    bytes memory transientContractInitializationCode
  ) {
    return _transientContractInitializationCode;
  }

  /**
   * @dev Función Ver para recuperar el hash keccak256 del código de inicialización de los contratos
   * transitorios a efectos de verificación.
   */
  function getTransientContractInitializationCodeHash() external view returns (
    bytes32 transientContractInitializationCodeHash
  ) {
    return _transientContractInitializationCodeHash;
  }

  /**
   * @dev Función Ver interna para calcular una dirección de contrato metamórfico dado para la una salt
   * en particular.
   */
  function _getMetamorphicContractAddress(
    bytes32 salt
  ) internal view returns (address) {
    // determine the address of the metamorphic contract.
    // determina la dirección del contrato metamórfico.
    return address(
      uint160(                      // downcast para que coincida con el tipo de dirección.
        uint256(                    // convertir a uint para truncar los dígitos superiores.
          keccak256(                // calcula el hash CREATE2 utilizando 4 entradas.
            abi.encodePacked(       // empaquetar todas las entradas al hash justas.
              hex"ff",              // comienza con 0xff para distinguirlo de RLP.
              address(this),        // éste contrato será el "llamador".
              salt,                 // pasa el valor de salt proporcionado.
              _metamorphicContractInitializationCodeHash // el hash del código de inicio.
            )
          )
        )
      )
    );
  }

  /**
   * @dev Función de vista interna para calcular una dirección de contrato transitoria
   * dada una salt particular.
   */
  function _getTransientContractAddress(
    bytes32 salt
  ) internal view returns (address) {
    // determina la dirección del contrato transitorio.
    return address(
      uint160(                      // downcast para que coincida con el tipo de dirección.
        uint256(                    // convertir a uint para truncar los dígitos superiores.
          keccak256(                // calcula el hash CREATE2 utilizando 4 entradas.
            abi.encodePacked(       // empaqueta todas las entradas al hash juntas.
              hex"ff",              // comienzaz con 0xff para distinguirlo de RLP.
              address(this),        // éste contrato será el "llamador".
              salt,                 // pasa el cvalor de salt proporcionado.
              _transientContractInitializationCodeHash // proporciona el hash del código de inicio.
            )
          )
        )
      )
    );
  }

  /**
   * @dev Función de vista interna para calcular una dirección de contrato metamórfico
   * que se ha implementado a través de un contrato transitorio dada la dirección del
   * contrato transitorio.
   */
  function _getMetamorphicContractAddressWithConstructor(
    address transientContractAddress
  ) internal pure returns (address) { 
    // determine the address of the metamorphic contract.
    // determina la dirección del contrato metamórfico.
    return address(
      uint160(                          // downcast para que coincida con el tipo de dirección.
        uint256(                        // establecer en uint para truncar los dígitos superiores.
          keccak256(                    // calcula CREATE hash mediante codificación RLP.
            abi.encodePacked(           // empaqueta todas las entradas al hash juntas.
              byte(0xd6),               // primer byte RLP.
              byte(0x94),               // segundo byte RLP.
              transientContractAddress, // lladamo por el contrato transitorio.
              byte(0x01)                // nonce comienza en 1 para contratos.
            )
          )
        )
      )
    );
  }

  /**
   * @dev Función Modifier para garantizar que los primeros 20 bytes de un salt enviado coincidan
   * con los de la cuenta que los llama. Esto proporciona protección contra la salt.
   * @param salt bytes32 El valor de salt para comparar con la dirección de llamada.
   */
  modifier containsCaller(bytes32 salt) {
    // evitar que los envíos de contratos sean robados de tx.pool requiriendo
    // que los primeros 20 bytes de salt enviados coincidan con msg.sender.
    require(
      address(bytes20(salt)) == msg.sender,
      "Salt no válido: los primeros 20 bytes de salt deben coincidir con la dirección de llamada."
    );
    _;
  }
}
