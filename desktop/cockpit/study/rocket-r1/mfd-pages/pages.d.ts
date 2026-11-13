export interface Page {id:string;title:string;render(data:unknown,ui:unknown):string;optionKeys?(ui:unknown,data:unknown):unknown[]}
