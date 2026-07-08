/**
 * ElaroGDPRException - Shared exception class for GDPR operations
 * 
 * Used by:
 * - ElaroGDPRDataPortabilityService
 * - ElaroGDPRDataErasureService
 * - Other GDPR-related services
 * 
 * @author Elaro
 * @version 1.0
 * @since v3.1.0 (Spring '26)
 * @group Compliance Framework
 */
public with sharing class ElaroGDPRException extends Exception {}
