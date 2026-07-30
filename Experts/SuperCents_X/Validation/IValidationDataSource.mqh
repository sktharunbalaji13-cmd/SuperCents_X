#ifndef __I_VALIDATION_DATA_SOURCE_MQH__
#define __I_VALIDATION_DATA_SOURCE_MQH__

#include "ValidationTypes.mqh"

class IValidationDataSource
{
public:
    virtual ~IValidationDataSource() {}

    virtual bool Prepare(const ValidationRequest &req) = 0;
    virtual bool Finalize(ValidationResult &outResult) = 0;
    virtual void Shutdown(void) = 0;
    virtual string GetStatus(void) const = 0;
};

#endif
