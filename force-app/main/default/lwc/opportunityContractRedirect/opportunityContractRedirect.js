import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import STAGE_FIELD      from '@salesforce/schema/Opportunity.StageName';
import CONTRACT_FIELD   from '@salesforce/schema/Opportunity.ContractId';
import CONTRACT_NUM     from '@salesforce/schema/Opportunity.Contract.ContractNumber';

const SESSION_KEY = 'opp_contract_redirected_';

export default class OpportunityContractRedirect extends NavigationMixin(LightningElement) {
    @api recordId;
    @track showToast = false;
    @track contractNumber = '';

    _redirected = false;

    @wire(getRecord, { recordId: '$recordId', fields: [STAGE_FIELD, CONTRACT_FIELD, CONTRACT_NUM] })
    wiredOpp({ data }) {
        if (!data) return;

        const stage      = getFieldValue(data, STAGE_FIELD);
        const contractId = getFieldValue(data, CONTRACT_FIELD);
        const sessionKey = SESSION_KEY + this.recordId;

        // Déclencher uniquement si Closed Won + ContractId présent + pas déjà redirigé dans cette session
        if (stage === 'Closed Won' && contractId && !sessionStorage.getItem(sessionKey) && !this._redirected) {
            this._redirected = true;
            sessionStorage.setItem(sessionKey, '1');

            this.contractNumber = getFieldValue(data, CONTRACT_NUM) || '';
            this.showToast = true;

            // Délai court pour laisser le temps à l'UI de se rafraîchir avant navigation
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId:   contractId,
                        actionName: 'edit'
                    }
                });
            }, 1500);
        }
    }
}
