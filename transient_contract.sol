pragma solidity 0.5.6;


/**
 * @title Interfaz de fábrica de contratos metamórficos
 * @notice Una interfaz para el contrato de fábrica que contiene una referencia al
 * código de inicialización que será utilizado por el contrato transitorio para implementar
 * el contrato metamórfico.
 */
interface FactoryInterface {
  function getInitializationCode() external view returns (
    bytes memory initializationCode
  );
}


/**
 * @title Contrato transitorio
 * @author William Khepri
 * @notice Este contrato creará un contrato metamórfico o un contrato de 
 * actualización que no depende de un proxy transparente, cuando se implementa utilizando
 * CREATE2. A difrerencia de los proxies transparentes actualizables, el estado de un
 * contrato metamórfico se eliminará con cada actualización. El contrato metamórfico también
 * puede utilizar un constructor si lo desea. Un gran poder conlleva una gran resposabilidad:
 * implemente los controles adecuados y eduque a los usuarios de sus contratos si interactúan con él.
 */
contract TransientContract {
  /**
   * @dev En el constructor, recupere el código de inicialización para la nueva
   * versión del contrato metamórfico, úsela para implementar el contrato metamórfico
   * mientras reenvía cualquier valor, y destruye el contrato transitorio.
   */
  constructor() public payable {
    // recupera la dirección de implementación de destino del creador de este contrato.
    bytes memory initCode = FactoryInterface(msg.sender).getInitializationCode();

    // configura una ubicación de memoria para la dirección del nuevo contrato metamórfico.
    address payable metamorphicContractAddress;

    // implementar la dirección del contrato metamórfico utilizando el código de inicio proporcionado.
    /* solhint-disable no-inline-assembly */
    assembly {
      let encoded_data := add(0x20, initCode) // cargar el código de inicialización.
      let encoded_size := mload(initCode)     // cargar la longitud del código de inicio.
      metamorphicContractAddress := create(   // llama a CREATE con 3 argumentos.
        callvalue,                            // reenvía cualquier dotación proporcionada.
        encoded_data,                         // pasa el código de inicialización.
        encoded_size                          // pasa la longitud del código de inicio.
      )
    } /* solhint-enable no-inline-assembly */

    // asegúrese de que el contrato metamórfico se haya implementado correctamente.
    require(metamorphicContractAddress != address(0));

    // destruye el contrato transitorio y reenvía todo el valor al contrato metamórfico.
    selfdestruct(metamorphicContractAddress);
  }
}
