<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="text" encoding="UTF-8" indent="no"/>

    <!-- Default values -->
    <xsl:param name="defaultRecipientType" select="'INDIVIDUAL'"/>
    <xsl:param name="defaultCurrency" select="'EUR'"/>
    <xsl:param name="defaultCountry" select="'NL'"/>
    <xsl:param name="defaultState" select="''"/>
    <xsl:param name="defaultAddressLine2" select="''"/>
    <xsl:param name="defaultCity" select="''"/>
    <xsl:param name="defaultPostalCode" select="''"/>

    <!-- Template to escape double quotes in a field -->
    <xsl:template name="escape-quotes">
        <xsl:param name="text"/>
        <xsl:choose>
            <xsl:when test="contains($text, '&quot;')">
                <xsl:value-of select="concat(substring-before($text, '&quot;'), '&quot;&quot;', substring-after($text, '&quot;'))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$text"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Template to escape CSV fields -->
    <xsl:template name="escape-csv">
        <xsl:param name="text"/>
        <xsl:variable name="escaped-text">
            <xsl:call-template name="escape-quotes">
                <xsl:with-param name="text" select="$text"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="contains($escaped-text, ',') or contains($escaped-text, '&quot;') or contains($escaped-text, '&#xA;')">
                <xsl:value-of select="concat('&quot;', $escaped-text, '&quot;')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$escaped-text"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Template: normalize a name field.
         - Trims whitespace.
         - If formatted as "last, first", swaps it to "first last". -->
    <xsl:template name="normalize-name">
        <xsl:param name="text"/>
        <xsl:variable name="trimmed" select="normalize-space($text)"/>
        <xsl:choose>
            <xsl:when test="contains($trimmed, ',')">
                <xsl:value-of select="normalize-space(concat(
                    substring-after($trimmed, ','),
                    ' ',
                    substring-before($trimmed, ',')
                ))"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$trimmed"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Template to trim whitespace and newlines -->
    <xsl:template name="trim">
        <xsl:param name="text"/>
        <xsl:value-of select="normalize-space($text)"/>
    </xsl:template>

    <!-- Match the root of the SEPA XML -->
    <xsl:template match="/">
        <!-- Header line -->
        <xsl:text>Name,Recipient type,IBAN,BIC,Recipient bank country,Currency,Amount,Payment reference,Recipient country,State or province,Address line 1,Address line 2,City,Postal code&#xA;</xsl:text>

        <!-- Process each transaction -->
        <xsl:for-each select="//*[local-name()='CdtTrfTxInf']">
            <!-- Name: trimmed, and "last, first" swapped back to "first last" -->
            <xsl:variable name="name">
                <xsl:variable name="normalized">
                    <xsl:call-template name="normalize-name">
                        <xsl:with-param name="text" select="*[local-name()='Cdtr']/*[local-name()='Nm']"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="$normalized"/>
                </xsl:call-template>
            </xsl:variable>

            <!-- Recipient type: determined by Cdtr/Id structure
                 - PrvtId present  -> INDIVIDUAL
                 - OrgId present   -> BUSINESS
                 - neither present -> defaultRecipientType -->
            <xsl:variable name="recipientType">
                <xsl:choose>
                    <xsl:when test="*[local-name()='Cdtr']/*[local-name()='Id']/*[local-name()='PrvtId']">
                        <xsl:value-of select="'INDIVIDUAL'"/>
                    </xsl:when>
                    <xsl:when test="*[local-name()='Cdtr']/*[local-name()='Id']/*[local-name()='OrgId']">
                        <xsl:value-of select="'BUSINESS'"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$defaultRecipientType"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <!-- All other fields unchanged -->
            <xsl:variable name="iban">
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="*[local-name()='CdtrAcct']/*[local-name()='Id']/*[local-name()='IBAN']"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:variable name="bic">
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="*[local-name()='CdtrAgt']/*[local-name()='FinInstnId']/*[local-name()='BIC']"/>
                </xsl:call-template>
            </xsl:variable>
            <!-- Recipient bank country:
                 1. Explicit Ctry element in CdtrAgt/FinInstnId (if present)
                 2. First 2 characters of the IBAN
                 3. defaultCountry as last resort -->
            <xsl:variable name="ibanRaw" select="normalize-space(*[local-name()='CdtrAcct']/*[local-name()='Id']/*[local-name()='IBAN'])"/>
            <xsl:variable name="bankCountry">
                <xsl:choose>
                    <!-- Use the explicit Ctry element if present -->
                    <xsl:when test="normalize-space(*[local-name()='CdtrAgt']/*[local-name()='FinInstnId']/*[local-name()='Ctry']) != ''">
                        <xsl:call-template name="escape-csv">
                            <xsl:with-param name="text" select="*[local-name()='CdtrAgt']/*[local-name()='FinInstnId']/*[local-name()='Ctry']"/>
                        </xsl:call-template>
                    </xsl:when>
                    <!-- Otherwise derive from IBAN's first 2 characters -->
                    <xsl:when test="$ibanRaw != ''">
                        <xsl:call-template name="escape-csv">
                            <xsl:with-param name="text" select="substring($ibanRaw, 1, 2)"/>
                        </xsl:call-template>
                    </xsl:when>
                    <!-- Last resort: default -->
                    <xsl:otherwise>
                        <xsl:value-of select="$defaultCountry"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="currency">
                <xsl:choose>
                    <xsl:when test="*[local-name()='Amt']/@Ccy">
                        <xsl:value-of select="*[local-name()='Amt']/@Ccy"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$defaultCurrency"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>
            <xsl:variable name="amount">
                <xsl:variable name="trimmed-amount">
                    <xsl:call-template name="trim">
                        <xsl:with-param name="text" select="*[local-name()='Amt']"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="$trimmed-amount"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:variable name="paymentReference">
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="*[local-name()='RmtInf']/*[local-name()='Ustrd']"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:variable name="recipientCountry">
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='Ctry']"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:variable name="state" select="$defaultState"/>

            <!-- Address Line 1: prioritize AdrLine[1], fallback to StrtNm + BldgNb -->
            <xsl:variable name="addressLine1">
                <xsl:choose>
                    <xsl:when test="*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='AdrLine'][1]">
                        <xsl:call-template name="escape-csv">
                            <xsl:with-param name="text" select="*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='AdrLine'][1]"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="escape-csv">
                            <xsl:with-param name="text" select="concat(*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='StrtNm'], ' ', *[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='BldgNb'])"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <!-- Address Line 2: prioritize AdrLine[2], fallback to empty -->
            <xsl:variable name="addressLine2">
                <xsl:choose>
                    <xsl:when test="*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='AdrLine'][2]">
                        <xsl:call-template name="escape-csv">
                            <xsl:with-param name="text" select="*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='AdrLine'][2]"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$defaultAddressLine2"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:variable>

            <xsl:variable name="city">
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='TwnNm']"/>
                </xsl:call-template>
            </xsl:variable>
            <xsl:variable name="postalCode">
                <xsl:call-template name="escape-csv">
                    <xsl:with-param name="text" select="*[local-name()='Cdtr']/*[local-name()='PstlAdr']/*[local-name()='PstCd']"/>
                </xsl:call-template>
            </xsl:variable>

            <!-- Output comma-separated line -->
            <xsl:value-of select="concat(
                $name, ',',
                $recipientType, ',',
                $iban, ',',
                $bic, ',',
                $bankCountry, ',',
                $currency, ',',
                $amount, ',',
                $paymentReference, ',',
                $recipientCountry, ',',
                $state, ',',
                $addressLine1, ',',
                $addressLine2, ',',
                $city, ',',
                $postalCode, '&#xA;'
            )"/>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
