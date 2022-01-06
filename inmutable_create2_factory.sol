pragma solidity 0.5.6;


/**
 * @title Immutable Create2 Contract Factory
 * @author William Khepri
 * @notice Este contrato proporciona una función safeCreate2 que toma un valor de sal
 * y un bloque de código de inicialización como argumentos y los pasa a la línea
 * montaje. El contrato evita los redespliegues manteniendo un mapeo de todos los
 * contratos que ya se han implementado, y previene la ejecución inicial u otras
 * colisiones al requerir que los primeros 20 bytes de la sal sean iguales a los
 * de la dirección que la llama (esto se puede omitir configurando los primeros 20 bytes como
 * dirección nula). También hay una función de vista que calcula la dirección de 
 * el contrato que se creará al enviar una determinada sal o nonce junto 
 * con un bloque dado de código de inicialización.
 * @dev CREATE2 no estará disponible en mainnet hasta (al menos) el bloque
 * 7.280.000. Este contrato aún no ha sido completamente probado o auditado - proceda
 * con precaución y comparta cualquier vulnerabilidad u optimización que descubra. 
 */
contract ImmutableCreate2Factory {
  // mapeo para rastrear qué direcciones ya se han implementado.
  mapping(address => bool) private _deployed;

  /**
   * @dev Crea un contrato utilizando CREATE2 enviando un salt o nonce dado
   * junto con el código de inicialización del contrato. Tenga en cuenta que los primeros 20
   * bytes de la sal deben coincidir con los de la dirección de llamada, lo que evita
   * los eventos de creación de contratos no sean enviados por partes no deseadas.
   * @param salt bytes32 El nonce que se pasará a la llamada de CREATE2.
   * @param initializationCode bytes El código cd inicialización que se pasará 
   * en la llamada de CREATE2.
   * @return Dirección del contrato que se creará, o la dirección que se pasará 
   * en la llamada a CREATE2.
   * @return Dirección del contrato que se creará, o la dirección nula
   * si ya existe un contrato en esa dirección.
   */
  function safeCreate2(
    bytes32 salt,
    bytes calldata initializationCode
  ) external payable containsCaller(salt) returns (address deploymentAddress) {
    // mueve el código de inicialización de calldata a la memoria.
    bytes memory initCode = initializationCode;

    // determina la dirección de destino para la implementación del contrato.
    address targetDeploymentAddress = address(
      uint160(                    // downcast para que coincida con el tipo de dirección.
        uint256(                  // convertir a uint para truncar los dígitos superiores.
          keccak256(              // calcula el hash CREATE2 usando 4 entradas.
            abi.encodePacked(     // empaqueta todas las entradas al hash juntas.
              hex"ff",            // comienza con 0xff para distinguirlo de RLP.
              address(this),      // este contrato será el que realiza la llamada.
              salt,               // pasa el valor de la sal proporcionado.
              keccak256(          // pasar el hash del código de inicialización.
                abi.encodePacked(
                  initCode
                )
              )
            )
          )
        )
      )
    );

    // asegúrate de que no se haya implementado previamente un contrato en la dirección de destino.
    require(
      !_deployed[targetDeploymentAddress],
      "Creación de contrato no válida: el contrato ya se ha implementado."
    );

    // usando ensamblado en líena: cargue los datos y la logitud de los datos, luego llame a CREATE2.
    assembly {                                // solhint-disable-line
      let encoded_data := add(0x20, initCode) // cargar el código de inicialización.
      let encoded_size := mload(initCode)     // carga la longitud del código de inicio.
      deploymentAddress := create2(           // llama a CREATE2 con 4 argumentos.
        callvalue,                            // reenvía cualquier valor adjunto.
        encoded_data,                         // pasa el código de inicialización.
        encoded_size,                         // pasa la longitud del código de inicio.
        salt                                  // pasa el valor de la sal.
      )
    }

    // verifica la dirección con el objetivo para asegurarse de que la implementación se haya realizado correctamente.
    require(
      deploymentAddress == targetDeploymentAddress,
      "Failed to deploy contract using provided salt and initialization code."
    );

    // registra el despligue del contrato para evitar redespliegues.
    _deployed[deploymentAddress] = true;
  }

  /**
   * @dev Calcula la dirección del contrato que se creará cuando
   * presentar una sal o un nonce determinados al contrato junto con el contrato.
   * código de inicialización. La dirección CREATE2 se calcula de acuerdo con
   * EIP-1014, y se adhiere a su fórmula de 
   * `keccak256 (0xff ++ dirección ++ sat ++ keccak25 (init_code))) [12:]` cuando
   * realizar el cálculo. A continuación, se comprueba la dirección calculada para
   * código de contrato existente: si es así, se devolverá la dirección nula.
   * @param salt bytes32 El nonce pasó al cálculo de la dirección CREATE2.
   * @param initCode bytes El código de inicialización del contrato que se utilizará.
   * @return Dirección del contrato que se creará, o la dirección nula
   * si ya se ha desplegado un contrato en esa dirección.
   */
  function findCreate2Address(
    bytes32 salt,
    bytes calldata initCode
  ) external view returns (address deploymentAddress) {
    // determina la dirección donde se implementará el contrato.
    deploymentAddress = address(
      uint160(                      // downcast para que coincida con el tipo de dirección.
        uint256(                    // convertir a uint para truncar los dígitos superiores.
          keccak256(                // calcula el hash CREATE2 usando 4 entradas.
            abi.encodePacked(       // empaqueta todas las entradas al hash juntas.
              hex"ff",              // comienza con 0xff para distinguirlo de RLP.
              address(this),        // este contrato será el llamador.
              salt,                 // pasa el valor de sal proporcionado.
              keccak256(            // pasar el hash del código de incialización.
                abi.encodePacked(
                  initCode
                )
              )
            )
          )
        )
      )
    );

    // devuelve una dirección nula para indicar un fallo si se ha implementado el contrato.
    if (_deployed[deploymentAddress]) {
      return address(0);
    }
  }

  /**
   * @dev Calcula la dirección del contrato que se creará cuando
   * enviar una sal o un nonce determinados al contrato junto con el hash keccak256
   * del código de inicialización del contrato. Se calcula la dirección CREATE2 
   * de acuerdo con EIP-1014, y se adhiere a la fórmula que contiene de 
   * `keccak256 (0xff ++ dirección ++ salt ++ keccak256 (init_code))) [12:]` cuando
   * realizar el cálculo. A continuación, se comprueba la dirección calculada para
   * el código del contrato existente: si es así, se devolverá la dirección nula.
   * @param salt bytes32 El nonce pasó al cálculo de la dirección CREATE2.
   * @param initCodeHash bytes32 El hash keccak256 del código de inicialización 
   * que se pasará al cálculo de la dirección CREATE2.
   * @return Dirección del contrato que se creará, o la dirección nula
   * si ya se ha desplegado un contrato en esa dirección.
   */
  function findCreate2AddressViaHash(
    bytes32 salt,
    bytes32 initCodeHash
  ) external view returns (address deploymentAddress) {
    // determina la dirección donde se implementará el contrato.
    deploymentAddress = address(
      uint160(                      // downcast para que coincida con el tipo de dirección.
        uint256(                    // convertir a uint para truncar los dígitos superiores.
          keccak256(                // calcula el hash CREATE2 usando 4 entradas.
            abi.encodePacked(       // empaqueta todas las entradas al hash juntas.
              hex"ff",              // comienza con 0xff para distinguirlo de RLP.
              address(this),        // este contrato será el llamador.
              salt,                 // pasa el valor de sal proporcionado.
              initCodeHash          // pasa el hash del código de inicialización.
            )
          )
        )
      )
    );

    // devuelve una dirección nula para indicar un fallo si se ha implementado el contrato.
    if (_deployed[deploymentAddress]) {
      return address(0);
    }
  }

  /**
   * @dev Determinar si la fábrica ya ha implementado un contrato en una
   * dirección dada.
   * @param deploymentAddress address La dirección del contrato para verificar.
   * @return True si el contrato se ha implementado, falso en caso contrario.
   */
  function hasBeenDeployed(
    address deploymentAddress
  ) external view returns (bool) {
    // determina si un contrato se ha implementado en la dirección proporcionada.
    return _deployed[deploymentAddress];
  }

  /**
   * @dev Modifier para garantizar que los primeros 20 bytes de un salt enviado coincidan
   * con los de la cuenta que llama. Esto proporciona protección contra que la sal
   * pueda ser robada por pioneros o atacantes. La protección también puede ser
   * bypaseada si se desea estableciendo cada uno de los primeros 20 bytes a cero.
   * @param salt bytes32 El valor de sal para comparar con la dirección de llamada.
   */
  modifier containsCaller(bytes32 salt) {
    // evitar que los envíos de contratos sean robados de tx.pool requiriendo
    // que los primeros 20 bytes de salt enviado coincidan con msg.sender.
    require(
      (address(bytes20(salt)) == msg.sender) ||
      (bytes20(salt) == bytes20(0)),
      "Salt no válido: los primeros 20 bytes del salt deben coincidir con la dirección de llamada."
    );
    _;
  }
}
