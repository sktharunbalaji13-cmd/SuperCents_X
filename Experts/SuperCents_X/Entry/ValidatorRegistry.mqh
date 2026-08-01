#ifndef __VALIDATOR_REGISTRY_MQH__
#define __VALIDATOR_REGISTRY_MQH__

#include "Validators/IEntryValidator.mqh"

#define MAX_REGISTERED_VALIDATORS 24

class CValidatorRegistry
{
private:
    IEntryValidator *m_validators[MAX_REGISTERED_VALIDATORS];
    bool             m_enabled[MAX_REGISTERED_VALIDATORS];
    int              m_count;

public:
    CValidatorRegistry(void)
        : m_count(0)
    {
        for(int i = 0; i < MAX_REGISTERED_VALIDATORS; i++)
        {
            m_validators[i] = NULL;
            m_enabled[i] = true;
        }
    }

    ~CValidatorRegistry(void)
    {
        m_count = 0;
    }

    bool Register(IEntryValidator *validator)
    {
        if(validator == NULL)
            return false;
        if(m_count >= MAX_REGISTERED_VALIDATORS)
            return false;

        string name = validator.GetName();
        for(int i = 0; i < m_count; i++)
        {
            if(m_validators[i] != NULL && m_validators[i].GetName() == name)
                return false;
        }

        m_validators[m_count] = validator;
        m_enabled[m_count] = true;
        m_count++;
        return true;
    }

    bool Unregister(const string name)
    {
        for(int i = 0; i < m_count; i++)
        {
            if(m_validators[i] != NULL && m_validators[i].GetName() == name)
            {
                for(int j = i; j < m_count - 1; j++)
                {
                    m_validators[j] = m_validators[j + 1];
                    m_enabled[j] = m_enabled[j + 1];
                }
                m_count--;
                return true;
            }
        }
        return false;
    }

    bool SetEnabled(const string name, bool enabled)
    {
        for(int i = 0; i < m_count; i++)
        {
            if(m_validators[i] != NULL && m_validators[i].GetName() == name)
            {
                m_enabled[i] = enabled;
                return true;
            }
        }
        return false;
    }

    bool IsEnabled(const string name) const
    {
        for(int i = 0; i < m_count; i++)
        {
            if(m_validators[i] != NULL && m_validators[i].GetName() == name)
                return m_enabled[i];
        }
        return false;
    }

    int Count() const
    {
        return m_count;
    }

    int CountByCategory(ENUM_VALIDATOR_CATEGORY category) const
    {
        int catCount = 0;
        for(int i = 0; i < m_count; i++)
        {
            if(m_validators[i] != NULL && m_validators[i].GetCategory() == category)
                catCount++;
        }
        return catCount;
    }

    IEntryValidator *GetValidator(int index) const
    {
        if(index < 0 || index >= m_count)
            return NULL;
        return m_validators[index];
    }

    bool IsEnabledAt(int index) const
    {
        if(index < 0 || index >= m_count)
            return false;
        return m_enabled[index];
    }

    string ListValidators() const
    {
        string list = "";
        for(int i = 0; i < m_count; i++)
        {
            if(m_validators[i] != NULL)
            {
                if(i > 0) list += ", ";
                list += m_validators[i].GetName();
                if(!m_enabled[i])
                    list += "(disabled)";
            }
        }
        return list;
    }

    void Clear()
    {
        m_count = 0;
        for(int i = 0; i < MAX_REGISTERED_VALIDATORS; i++)
        {
            m_validators[i] = NULL;
            m_enabled[i] = true;
        }
    }
};

#endif
