pragma solidity 0.5.6;


/**
 * @title Metapod
 * @author William Khepri
 * @notice Este contrato crea contratos metamórficos "endurecidos"
 * que se pueden volver a implementar con un nuevo código en la misma dirección, con
 * protecciones contra la creación de contratos no metamórficos o la pérdida de equilibrio
 * mantenido por el contrato cuando se destruye. Lo hace configurando primero el 
 * código de inicialización de contrato deseado en un almacenamiento temporal. A continuación, 
 * se comprueba el saldo del contrato correspondiente a la dirección de destino, y si
 * uno existe se enviará a la dirección de un implementador intermedio, o un
 * contrato transitorio con código de inicialización fijo, no determinista. Una vez
 * implementado a través de CREATE2, el contrato transitorio recupera el código de inicialización
 * del almacenamiento y lo usa para implementar el contrato a través de CREATE, reenvia
 * el saldo total al nuevo contrato, y luego llama a SELFDESTRUCT. Finalmente, se 
 * comprueba el preludio del contrato para asegurarse de que se pueda autodestruir y se designa la vault
 * como dirección de reenvío. Una vez que el contrato sufre la metamorfosis, todo el almacenamiento
 * existente se eliminará y cualquier saldo se enviará a la vault que luego puede reabastecer el contrato
 * el contrato metamórfico en el momento de la redistribución.
 * @dev Este contrato aún no ha sido completamente probado o auditado - continúe
 * con precaución y por favor comparta cualquier exploit u optimización que descubra.
 * Además, tenga en cuenta que cualquier código de inicialización proporcionado al contrato debe
 * contener el preludio adecuado, o secuencia inicial, con una longitud de 44 bytes: 
 *
 * `0x6e03212eb796dee588acdbbbd777d4e73318602b5773 + vault_address + 0xff5b`
 *
 * Para la dirección de la vault requerida, use  `findVaultContractAddress (bytes32 salt)`.
 * Cualquier código de inicialización generado por Solidity u otro compilador necesitará
 * para que se modifiquen los elementos de pila proporcionados a JUMP, JUMPI y CODECOPY
 * apropiadamente al insertar este código, y es posible que también deba modificar algunos PC
 * operaciones (especialmente si no es código Solidity). Tenga en cuenta que los contratos
 * siguen siendo accesibles después de que se haya programado su eliminación hasta que 
 * dicha transacción se completa, y ese Ether aún se les puede enviar, ya que el
 * paso de reenvío de fondos se realiza de inmediato, no como parte de la transacción subestable
 * con la eliminación de la cuenta. Si esos fondos no se mueven a una cuenta no destruible al final de la 
 * transacción, serán quedamos irreversiblemente. Por último, debido a la mecánicade SELFDESTRUCT, un contrato
 * no se puede destruir y volver a implementar en una sola transacción, para evitar
 * "tiempo de inactividad" del contrato, considere utilizar varios contratos y tener 
 * las personas que llaman y que determinan el contrato actual utilizando EXTCODEHASH.
 */
contract Metapod {
  // se ejecuta cuando se implementa un contrato metamórfico.
  event Metamorphosed(address metamorphicContract, bytes32 salt);

  //se ejecuta cuando se destruye un contrato metamórfico.
  event Cocooned(address metamorphicContract, bytes32 salt);

  // código de inicialización para contrato transitorio para implementar contratos metamórficos.
  /* ##  op  operation        [stack] <memory> {return_buffer} *contract_deploy*
     00  58  PC               [0]
     01  60  PUSH1 0x1c       [0, 28]
     03  59  MSIZE            [0, 28, 0]
     04  58  PC               [0, 28, 0, 4]
     05  59  MSIZE            [0, 28, 0, 4, 0]
     06  92  SWAP3            [0, 0, 0, 4, 28]
     07  33  CALLER           [0, 0, 0, 4, 28, caller]
     08  5a  GAS              [0, 0, 0, 4, 28, caller, gas]
     09  63  PUSH4 0x57b9f523 [0, 0, 0, 4, 28, caller, gas, selector]
     14  59  MSIZE            [0, 0, 0, 4, 28, caller, gas, selector, 0]
     15  52  MSTORE           [0, 0, 0, 4, 28, caller, gas] <selector>
     16  fa  STATICCALL       [0, 1 => success] {init_code}
     17  50  POP              [0]
     18  60  PUSH1 0x40       [0, 64]
     20  30  ADDRESS          [0, 64, address]
     21  31  BALANCE          [0, 64, balance]
     22  81  DUP2             [0, 64, balance, 64]
     23  3d  RETURNDATASIZE   [0, 64, balance, 64, size]
     24  03  SUB              [0, 64, balance, size - 64]
     25  83  DUP4             [0, 64, balance, size - 64, 0]
     26  92  SWAP3            [0, 0, balance, size - 64, 64]
     27  81  DUP2             [0, 0, balance, size - 64, 64, size - 64]
     28  94  SWAP5            [size - 64, 0, balance, size - 64, 64, 0]
     29  3e  RETURNDATACOPY   [size - 64, 0, balance] <init_code>
     30  f0  CREATE           [contract_address or 0] *init_code*
     31  80  DUP1             [contract_address or 0, contract_address or 0]
     32  15  ISZERO           [contract_address or 0, 0 or 1]
     33  60  PUSH1 0x25       [contract_address or 0, 0 or 1, 37]
     35  57  JUMPI            [contract_address]
     36  ff  SELFDESTRUCT     []
     37  5b  JUMPDEST         [0]
     38  80  DUP1             [0, 0]
     39  fd  REVERT           []
  */
  bytes private constant TRANSIENT_CONTRACT_INITIALIZATION_CODE = (
    hex"58601c59585992335a6357b9f5235952fa5060403031813d03839281943ef08015602557ff5b80fd"
  );

  //almacena el hash del código de inicialización para contratos transitorios.
  bytes32 private constant TRANSIENT_CONTRACT_INITIALIZATION_CODE_HASH = bytes32(
    0xb7d11e258d6663925ce8e43f07ba3b7792a573ecc2fd7682d01f8a70b2223294
  );

  // el "hash de datos vacío" se utiliza para determinar si la vault se ha implementado.
  bytes32 private constant EMPTY_DATA_HASH = bytes32(
    0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
  );

  // mantener una ranura de almacenamiento temporar para el código de inicialización metamórfico.
  bytes private _initCode;

  constructor() public {
    // asegúrese de que la dirección de implementación sea correcta.
    // factory: 0x2415e7092bC80213E128536E6B22a54c718dC67A
    // caller: 0xaFD79DB96D018f333deb9ac821cc170F5cc81Ea8
    // init code hash: 0x8954ff8965dbf871b7b4f49acc85a2a7c96c93ebc16ba59a4d07c52d8d0b6ec2
    // salt: 0xafd79db96d018f333deb9ac821cc170f5cc81ea810f74f2d75490b0486060000
    require(
      address(this) == address(0x000000000003212eb796dEE588acdbBbD777D4E7),
      "Dirección de implementación incorrecta."
    );

    // asegúrese de que el valor de la constante hash del código de inicialización transitoria sea correcto.
    require(
      keccak256(
        abi.encodePacked(TRANSIENT_CONTRACT_INITIALIZATION_CODE)
      ) == TRANSIENT_CONTRACT_INITIALIZATION_CODE_HASH,
      "Hash incorrecto para el código de inicialización transitorio."
    );

    // asegúrese de que el valor de la constante hash de datos vacíos sea correcta.
    require(
      keccak256(abi.encodePacked(hex"")) == EMPTY_DATA_HASH,
      "Hash incorrecto para datos vacíos."
    );
  }

  /**
   * @dev Implementa un contrato metamórfico enviando un salt o nonce determinado
   * junto con el código de inicialización a un contrato transitorio que luego 
   * implementa el contrato metamórfico antes de autodestruirse inmediatamente.
   * Para reemplazar el contrato metamórfico, llamar a la función destroy() con el mismo
   * valor de salt, y luego llamar con el mismo valor de salt y un nuevo código de inicialización
   * (tenga en cuenta que todo el estado existente será eliminado del contrato).
   * @param identifier uint96 Los últimos doce bytes de la salt que serán
   * pasados a la llamada de CREATE2 (con los primeros veinte bytes del conjunto de salt a 'msg.sender')
   * y así determinará la dirección resultante del contrato metamórfico.
   * @param initializationCode bytes El código de inicialización para el contrato metamórfico
   * que será implementado por el contrato transitorio.
   * @return La dirección del contrato metamórfico desplegado.
   */
  function deploy(
    uint96 identifier,
    bytes calldata initializationCode
  ) external payable returns (address metamorphicContract) {
    // calcula la salt utilizacndo el identificador proporcionado.
    bytes32 salt = _getSalt(identifier);

    // almacena el código de inicialización que será recuperado por el contrato transitorio.
    _initCode = initializationCode;

    // obtiene el contrato de vault y proporciona los fondos correspondientes al contrato transitorio.
    address vaultContract = _triggerVaultFundsRelease(salt);

    // declara variable para verificar la implementación existosa del contrato transitorio.
    address transientContract;

    // mueve el código de inicialización del contrato transitorio a la memoria.
    bytes memory initCode = TRANSIENT_CONTRACT_INITIALIZATION_CODE;

    // carga datos y tamaño de inicio del contrato transitorio, luego implementa a través de CREATE2.
    assembly { /* solhint-disable no-inline-assembly */
      let encoded_data := add(0x20, initCode) // carga el código de inicialización.
      let encoded_size := mload(initCode)     // carga la longitud del código de inicio.
      transientContract := create2(           // llama a CREATE2 con 4 argumentos.
        callvalue,                            // reenvía cualquier dotación proporcionada.
        encoded_data,                         // pasa el código de inicialización.
        encoded_size,                         // pasa la longitud del código de inicio.
        salt                                  // pasa el valor de la salt.
      )
    } /* solhint-enable no-inline-assembly */

    // asegurarse de que los contratos se hayan implementado correctamente.
    require(transientContract != address(0), "No se pudo implementar el contrato.");

    // obtener la dirección del contrato metamórfico desplegado.
    metamorphicContract = _getMetamorphicContractAddress(transientContract);

    // asegúrese de que el código de tiempo de ejecución implementado tenga el preludio requerido.
    _verifyPrelude(metamorphicContract, _getPrelude(vaultContract));

    // borra el código de inicialización proporcionado del almacenamiento temporal.
    delete _initCode;

    // Emite un evento para indicar que el contrato se implementó correctamente.
    emit Metamorphosed(metamorphicContract, salt);
  }

  /**
   * @dev Destruye un contrato metamórfico invocándolo, lo que activará
   * un SELFDESTRUCT y reenviará todos los fondos al contrato vault designado.
   * Sea consciente de que todo el estado existente será eliminado del contrato.
   * @param identifier uint96 Los últimos doce bytes de la salt que se pasó 
   * en la llamada a CREATE2 (con los primeros veinte bytes de la salt configurados en 'msg.sender')
   * que determinó la dirección resultante del contrato metamórfico.
   */
  function destroy(uint96 identifier) external {
    // calcula la salt utilizando el identificador proporcionado
    bytes32 salt = _getSalt(identifier);

    // determina la dirección del contrato metamórfico.
    address metamorphicContract = _getMetamorphicContractAddress(
      _getTransientContractAddress(salt)
    );

    // llamar al contrato para activar SELFDESTRUCT que reenvía los fondos al vault.
    metamorphicContract.call(""); /* solhint-disable-line avoid-low-level-calls */

    // Emite un evento para indicar que el contrato estaba programado para su eliminación.
    emit Cocooned(metamorphicContract, salt);
  }

  /**
   * @dev Recuperar los fondos de un contrato metamórfico, la vault asociada, 
   * y el contrato transitorio asociado mediante el despliegue de un contrato metamórfico dedicado
   * que enviará fondos a 'msg.sender' e inmediatamente llamará a SEFLDESTRUCT.
   * @param identifier uint96 Los últimos doce bytes de la salt que se pasó
   * en la llamada a CREATE2 (con los primeros veinte bytes de la sal configurados en 'msg.sender')
   * que determinó la dirección resultante del contrato metamórfico.
   */
  function recover(uint96 identifier) external {
    // calcula la salt utilizando el identificados proporcionado.
    bytes32 salt = _getSalt(identifier);

    //activar el contrato de la vault para enviar fondos al contrato transitorio.
    _triggerVaultFundsRelease(salt);

    // construye el código de inicialización del contrato de recuperación y lo coloca en el almacentamiento.
    _initCode = abi.encodePacked(
      bytes2(0x5873),  // PC PUSH20
      msg.sender,      // <la dirección que llama es el destinatario de los fondos>
      bytes13(0x905959593031856108fcf150ff)
        // SWAP1 MSIZEx3 ADDRESS BALANCE DUP6 PUSH2 2300 CALL POP SELFDESTRUCT
    );

    // declarar variable para verificar la implementación existosa del contrato transitorio.
    address transientContract;

    // mover el código de inicialización del contrato transitorio a la memoria.
    bytes memory initCode = TRANSIENT_CONTRACT_INITIALIZATION_CODE;

    // cargar datos y tamaño de inicio de contrato transitorio, luego implementar a través de CREATE2.
    assembly { /* solhint-disable no-inline-assembly */
      let encoded_data := add(0x20, initCode) // carga el código de inicialización.
      let encoded_size := mload(initCode)     // carga la longitud del código de inicio.
      transientContract := create2(           // llama a CREATE2 con 4 argumentos.
        callvalue,                            // reenvía cualquier dotación proporcionada.
        encoded_data,                         // pasar el código de inicialización.
        encoded_size,                         // pasar la longitud del código de inicio.
        salt                                  // pasar el valor de la salt.
      )
    } /* solhint-enable no-inline-assembly */

    // asegúrese de que el contrato de recuperación se haya implementado correctamente.
    require(
      transientContract != address(0),
      "Falló la recuperación: asegúrese de que el contrato haya sido destruido."
    );

    // borrar el código de inicialización del contrato de recuperación del almacenamiento temporal.
    delete _initCode;
  }

  /**
   * @dev Ver función para recuperar el código de inicialización para un determinado
   * contrato metamórfico para desplegar a través de un contrato transitorio. Llamado por el
   * contructor de cada contrato transitorio: no debe ser llamado por los usuarios.
   * @return El código de inicialización que se utilizará para implementar el contrato metamórfico.
   */
  function getInitializationCode() external view returns (
    bytes memory initializationCode
  ) {
    //devuelve el código de inicialización actual del almacenamiento temporal.
    initializationCode = _initCode;
  }

  /**
   * @dev Calcula la dirección del contrato transitorio que se creará
   * al someter una salt determinada al contrato.
   * @param salt bytes32 El nonce pasó a CREATE2 al implementar el 
   * contrato transitorio, compuesto por un identificador ++ de la persona que llama.
   * @return La dirección del contrato transitorio correspondiente.
   */
  function findTransientContractAddress(
    bytes32 salt
  ) external pure returns (address transientContract) {
    // determina la dirección donde se implementará el contrato transitorio.
    transientContract = _getTransientContractAddress(salt);
  }

  /**
   * @dev Calcula la dirección del contrato metamórfico que se creará
   * al someter una salt determinada al contrato.
   * @param salt bytes32 El nonce utilizado para crear el contrato transitorio que
   * despliega el contrato metamórfico, compuesto por el identificador de la persona que llama ++.
   * @return La dirección del correspondiente contrato metamórfico.
   */
  function findMetamorphicContractAddress(
    bytes32 salt
  ) external pure returns (address metamorphicContract) {
    // determina la dirección del contrato metamórfico.
    metamorphicContract = _getMetamorphicContractAddress(
      _getTransientContractAddress(salt)
    );
  }

  /**
   * @dev Calcula la dirección del contrato de la vault que se establecerá como
   * destinatario de fondos del contrato metamórfico cuando se destruye.
   * @param salt bytes32 El nonce utiliado para crear el contrato transitorio que
   * despliega el contrato metamórfico, compuesto por el identificador de la persona que llama ++.
   * @return La dirección del contrato de vault correspondiente.
   */
  function findVaultContractAddress(
    bytes32 salt
  ) external pure returns (address vaultContract) {
    vaultContract = _getVaultContractAddress(
      _getVaultContractInitializationCode(
        _getTransientContractAddress(salt)
      )
    );
  }

  /**
   * @dev Función View para recuperar el preludio que será necesario para cualquier
   * contrato metamórfico desplegado a través de una salt específica.
   * @param salt bytes32 El nonce utilizado para crear el contrato transitorio que
   * despliega el contrato metamórfico, compuesto por el identificador de la persona que llama ++.
   * @return El preludio que deberá estar presente al inicio del código de ejecución
   * implementado para cualquier contrato metamórfico implementado utilizando la salt proporcionada.
   */
  function getPrelude(bytes32 salt) external pure returns (
    bytes memory prelude
  ) {
    // calcula y devuelve el preludio.
    prelude = _getPrelude(
      _getVaultContractAddress(
        _getVaultContractInitializationCode(
          _getTransientContractAddress(salt)
        )
      )
    );
  }  

  /**
   * @dev Función View para recuperar el código de inicialización de contratos metamórficos
   * a efectos de verificación.
   * @return El código de inicialización utilizado para implementar contratos transitorios.
   */
  function getTransientContractInitializationCode() external pure returns (
    bytes memory transientContractInitializationCode
  ) {
    // devuelve el código de inicialización utilizado para implementar contratos transitorios.
    transientContractInitializationCode = (
      TRANSIENT_CONTRACT_INITIALIZATION_CODE
    );
  }

  /**
   * @dev Función View para recuperar el hash keccak256 de la inicialización
   * del código de contratos metamórficos a efectos de verificación.
   * @return El hash keccak256 del código de inicialización utilizado para implementar 
   * contratos transitorios.
   */
  function getTransientContractInitializationCodeHash() external pure returns (
    bytes32 transientContractInitializationCodeHash
  ) {
    // devuelve el hash del código de inicialización utilizado para implementar contratos transitorios.
    transientContractInitializationCodeHash = (
      TRANSIENT_CONTRACT_INITIALIZATION_CODE_HASH
    );
  }

  /**
   * @dev Función View para calcular una salt dada por una llamada en particular y un 
   * identificador.
   * @param identifier bytes12 Los últimos doce bytes de la salt (los primeros
   * veinte bytes se establecen en 'msg.sender').
   * @return La salt que se suministrará a CREATE2 al proporcionar 
   * el identificador de la cuenta que llama.
   */
  function getSalt(uint96 identifier) external view returns (bytes32 salt) {
    salt = _getSalt(identifier);
  }

  /**
   * @dev Función de View interna para calcular una salt dada por un caller particular 
   * y un identificador.
   * @param identifier bytes12 Los últimos 12 bytes de la salt (los primeros
   * veinte bytes se establecen en 'msg.sender').
   * @return La salt que se suministrará a CREATE2.
   */
  function _getSalt(uint96 identifier) internal view returns (bytes32 salt) {
    assembly { /* solhint-disable no-inline-assembly */
      salt := or(shl(96, caller), identifier) // caller: first 20, ID: last 12
    } /* solhint-enable no-inline-assembly */
  }

  /**
   * @dev Función interna para determinar el preludio requerido para contratos
   * metamórficos desplegados a través de la fábrica basados en el contrato vault correspondiente.
   * @param vaultContract address La dirección del contrato vault.
   * @return El preludio que se requerirá para otorgar un contrato de vault.
   */
  function _getPrelude(
    address vaultContract
  ) internal pure returns (bytes memory prelude) {
    prelude = abi.encodePacked(
      // PUSH15 <this> CALLER XOR PUSH1 43 JUMPI PUSH20
      bytes22(0x6e03212eb796dee588acdbbbd777d4e73318602b5773),
      vaultContract, // <vault is the approved SELFDESTRUCT recipient>
      bytes2(0xff5b) // SELFDESTRUCT JUMPDEST
    );
  }

  /**
   * @dev Función interna para determinar si el contrato metamórfico implementado tiene
   * el preludio necesario al comienzo del su código de tiempo de ejecución. El preludio asegura
   * que el contrato puede ser destruido por una llamada originada en este contrato
   * y que los fondos se remitirán al correspondiente contrato vault.
   * @param metamorphicContract address La dirección del contrato metamórfico.
   * @param prelude bytes El preludio que debe estar presente en el contrato.
   */
  function _verifyPrelude(
    address metamorphicContract,
    bytes memory prelude
  ) internal view {
    // obtiene los primero 44 bytes del código de tiempo de ejecución del contrato metamórfico.
    bytes memory runtimeHeader;

    assembly { /* solhint-disable no-inline-assembly */
      // establece y actualiza el puntero según el tamaño del encabezado en tiempo de ejecución.
      runtimeHeader := mload(0x40)
      mstore(0x40, add(runtimeHeader, 0x60))

      // almacena el código de tiempo de ejecución y la logitud en la memoria.
      mstore(runtimeHeader, 44)
      extcodecopy(metamorphicContract, add(runtimeHeader, 0x20), 0, 44)
    } /* solhint-enable no-inline-assembly */

    // asegúrese de que el código de ejecución del contrato tenga la secuencia inicial correcta.
    require(
      keccak256(
        abi.encodePacked(prelude)
      ) == keccak256(
        abi.encodePacked(runtimeHeader)
      ),
      "El código de tiempo de ejecución implementado no tiene el preludio requerido."
    );
  }

  /**
   * @dev Función interna para determinar si un contrato de vault tiene saldo
   * y traspaso del saldo al correspondiente contrato transitorio en su caso.
   * Esto se logra mediante la implementación del contrato de la vault si aún no existe ningún contrato
   * o llamando al contrato si ya se ha implementado.
   * @param salt bytes32 El nonce usado para crear el contrato transitorio que
   * despliega el contrato metamórfico asociado con una vault correspondiente.
   * @return La dirección del contrato de la vault.
   */
  function _triggerVaultFundsRelease(
    bytes32 salt
  ) internal returns (address vaultContract) {
    // determina la dirección del contrato transitorio.
    address transientContract = _getTransientContractAddress(salt);

    // determina el código de inicialización del contrato de la vault.
    bytes memory vaultContractInitCode = _getVaultContractInitializationCode(
      transientContract
    );

    // determina la dirección del contrato de la vault.
    vaultContract = _getVaultContractAddress(vaultContractInitCode);

    // determina si la vault tiene saldo.
    if (vaultContract.balance > 0) {
      // determina si la vault ya se ha implementado.
      bytes32 vaultContractCodeHash;

      assembly { /* solhint-disable no-inline-assembly */
        vaultContractCodeHash := extcodehash(vaultContract)
      } /* solhint-enable no-inline-assembly */

      // si no se ha implementado, impleméntelo para enviar fondos a transient.
      if (vaultContractCodeHash == EMPTY_DATA_HASH) {
        assembly { /* solhint-disable no-inline-assembly */
          let encoded_data := add(0x20, vaultContractInitCode) // código de inicio.
          let encoded_size := mload(vaultContractInitCode)     // logitud de inicialización.
          let _ := create2(                   // llamada a CREATE2.
            0,                                // no proporciona ninguna dotación.
            encoded_data,                     // pasa el código de inicialización.
            encoded_size,                     // pasa la longitud del código de inicio.
            0                                 // pasa cero como valor de salt.
          )
        } /* solhint-enable no-inline-assembly */
      // de lo contrario, simplemente llámelo, lo que también enviará fondos a transient.
      } else {
        vaultContract.call(""); /* solhint-disable-line avoid-low-level-calls */
      }
    }
  }

  /**
   * @dev Función de view interna para calcular una dirección de contrato transitoria
   * dada una salt particular.
   * @param salt bytes32 El nonce usado para crear el contrato transitorio.
   * @return La dirección del contrato transitorio.
   */
  function _getTransientContractAddress(
    bytes32 salt
  ) internal pure returns (address transientContract) {
    // determina la dirección del contrato transitorio.
    transientContract = address(
      uint160(                      // downcast para que coincida con el tipo de dirección.
        uint256(                    // convertir a uint para truncar los dígitos superiores.
          keccak256(                // calcula el hash CREATE2 utilizando 4 entradas.
            abi.encodePacked(       // empaqueta todas las entradas al hash juntas.
              hex"ff",              // comienza con 0xff para distinguirlo de RLP.
              address(0x000000000003212eb796dEE588acdbBbD777D4E7), // this.
              salt,                 // pasa el valor de salt proporcionado.
              TRANSIENT_CONTRACT_INITIALIZATION_CODE_HASH // el hash del código de inicio.
            )
          )
        )
      )
    );
  }

  /**
   * @dev Función de vista interna para calcular una dirección de contrato metamórfica
   * que se ha implementado a través de un contrato transitorio dada la dirección del contrato
   * transitorio.
   * @param transientContract address La dirección del contrato transitorio.
   * @return La dirección del contrato metamórfico.
   */
  function _getMetamorphicContractAddress(
    address transientContract
  ) internal pure returns (address metamorphicContract) {
    // determina la dirección del contrato metamórfico.
    metamorphicContract = address(
      uint160(                          // downcast para que coincida con el tipo de dirección.
        uint256(                        // establecer en uint para truncar los dígitos superiores.
          keccak256(                    // calcula CREATE hash mediante codificación RLP.
            abi.encodePacked(           // empaqueta todas las entradas de hash juntas.
              bytes2(0xd694),           // primeros dos bytes de RLP.
              transientContract,        // llamado por el contrato transitorio.
              byte(0x01)                // nonce comienza en 1 para contratos.
            )
          )
        )
      )
    );
  }

  /**
   * @dev Función de vista interna para calcular un código de inicialización para un
   * contrato de vault dado en base al contrato transitorio correspondiente.
   * @param transientContract address La dirección del contrato transitorio.
   * @return El código de inicialización para el contrato de la vault.
   */
  function _getVaultContractInitializationCode(
    address transientContract
  ) internal pure returns (bytes memory vaultContractInitializationCode) {
    vaultContractInitializationCode = abi.encodePacked(
      // PC PUSH15 <this> CALLER XOR PC JUMPI MSIZEx3 ADDRESS BALANCE PUSH20
      bytes27(0x586e03212eb796dee588acdbbbd777d4e733185857595959303173),
      // el contrato transitorio es el receptor de fondos
      transientContract,
      // GAS CALL PUSH1 49 MSIZE DUP2 MSIZEx2 CODECOPY RETURN
      bytes10(0x5af160315981595939f3)
    );
  }

  /**
   * @dev Función de view interna para calcular una dirección de contrato de vault dado
   * el código de inicialización para el contrato de vault.
   * @param vaultContractInitializationCode bytes El código de inicialización del contrato de vault.
   * @return La dirección del contrato de vault.
   */
  function _getVaultContractAddress(
    bytes memory vaultContractInitializationCode
  ) internal pure returns (address vaultContract) {
    // determina la dirección del contrato de vault.
    vaultContract = address(
      uint160(                      // downcast para que coincida con el tipo de dirección.
        uint256(                    // convertir a uint para truncar los dígitos superiores.
          keccak256(                // calcula el hash CREATE2 utilizando 4 entradas.
            abi.encodePacked(       // empaqueta todas las entradas al hash juntas.
              byte(0xff),           // comienza con 0xff para distinguir de RLP.
              address(0x000000000003212eb796dEE588acdbBbD777D4E7), // this.
              bytes32(0),           // deja el valor de la salt en cero.
              keccak256(            // hash del código de inicialización proporcionado.
                vaultContractInitializationCode
              )
            )
          )
        )
      )
    );
  }
}
