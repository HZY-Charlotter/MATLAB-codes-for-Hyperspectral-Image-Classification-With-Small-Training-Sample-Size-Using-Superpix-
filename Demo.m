function  Demo
%ZHENG C, WANG N, CUI J. Hyperspectral Image Classification With
% Small Training Sample Size Using Superpixel-Guided Training Sample
%Enlargement. IEEE Transactions on Geoscience and Remote Sensing,
% 2019: 57(10): 7307-7316.

clear
close all
%clc

%% data sets%%%%%%%%%%%%%%%%%%%%%%%%%%
%size:Indian(145*145) PaviaU(610*340) SalinasA(512*217) KSC(512*614)
dataNameSet={'Indian_pines_corrected','PaviaU','Salinas_corrected'};

%Superpixel numbers
SpNums=round([145*145/64 610*340/121 512*217/121 512*614/121]);
%SpNums=[300 1600 918 2500];

%lambda sets
LmdSets=[1e-3 1e-2 1e-2 1e-2 0.1 0.1;
    1e-3 1e-2 1e-2 1e-2 1e-2 1e-2;
    1e-4 1e-4 1e-4 1e-4 1e-4 1e-4];

expTimes=20;%20 Monte Carlo runs
Ps=[5 10 15 20 30 40];%training samples per class
lthP=length(Ps);

for nameNb=1:3
    numSuperpixels=SpNums(nameNb);
    %%
    dataName=dataNameSet{nameNb};
    load(dataName);%load data
    
    [row,col,dim]=size(data);
    nPixel=row*col;
    %% Convert to matrix and normalize%%%%%%%%
    X=zeros(dim,nPixel);
    js=1;
    for c=1:col
        for r=1:row
            x=reshape(data(r,c,:),dim,1);
            m=min(x);
            tmp=(x-m)/(max(x)-m);%Normalization
            X(:,js)=tmp;
            js=js+1;
        end
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%  Superpixel segmentation
    fileName=['data\SpSegm' dataName num2str(numSuperpixels)];
    if exist([fileName '.mat'],'file')
        load(fileName) %load superpixel segmentation results
    else
        [Sp,nSp]=SuperpixelSegmentation(data,numSuperpixels);
        save(fileName,'Sp','nSp')%save superpixel segmentation results
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%
    for pth=1:lthP
        P=Ps(pth);%P is one of [5 10 15 20 30]
        fileName=sprintf('Result%s%d.txt',dataName(1:6),P);
        for expT=1:expTimes
            nClass=max(label(:));
            %% ����ѵ�������Ͳ�������
            rng(expT*10,'twister');%�����������
            mask=false(row,col);%��֪����ģ
            nListTrn=zeros(nClass,1);%�����ѵ��������
            nListClass=zeros(nClass,1);%ÿ�����������
            idTst=[];
            labels=label;
            js=1;
            for c=1:nClass
                id=find(label==c);
                n=numel(id);
                if ~n,continue;end
                nListClass(js)=n;
                labels(id)=js;
                if P<1
                    ntrnc=max(round(P*n),1); %��c��ѵ��������
                else
                    ntrnc=P;
                end
                if ntrnc>=n
                    ntrnc=15;
                end
                nListTrn(js)=ntrnc;
                id1=randperm(n,ntrnc);
                mask(id(id1))=true;%��֪����ģ��mask(r,c)=true,��(r,c)��Ϊ��֪��
                id(id1)=[];
                idTst=[idTst; id];
                js=js+1;
            end
            %%%%
            nClass=js-1;
            nListTrn(js:end)=[];
            nListClass(js:end)=[];
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %idTrn0=find(mask);
            predictedLabel=zeros(row,col); %Ԥ��������
            predictedLabel(mask)=labels(mask);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            tic
            %% ���Ƚ���������ֻ����һ��ѵ�������ĳ�����ʶ��Ϊ����
            SpInfo.unrecg=true(nSp,1);%��¼�������Ƿ��Ѿ�ʶ��
            SpInfo.gIdx=cell(nSp,1);%�洢�������ص�����
            SpInfo.ntp=zeros(nSp,1,'uint16');%���������а�����ѵ�����������
            SpInfo.types=cell(nSp,1);%���������а�����ѵ���������
            for t=1:nSp
                idt= find(Sp==t & labels);%
                if isempty(idt)%�ó����ز���ʶ��
                    SpInfo.unrecg(t)=false;
                    SpInfo.gIdx{t}=[];
                    continue;
                end
                %�鿴�����Ƿ������֪�����
                id1=find(mask(idt));
                ns=numel(id1);
                if ns %���а���ѵ������
                    lablei=labels(idt(id1));
                    types=unique(lablei);
                    ntp=numel(types);
                    if ntp==1 %�����Ϊ1������������һ��ѵ������
                        %���ó�����ʶ��Ϊ��ѵ��������
                        predictedLabel(idt)=types;
                        SpInfo.unrecg(t)=false;
                        %����ʶ��������Ϊѵ������
                        mask(idt)=true;
                        continue;
                    end
                    % ��¼�ó�������Ϣ
                    SpInfo.ntp(t)=ntp;
                    SpInfo.types{t}=types;
                end
                SpInfo.gIdx{t}=idt;
            end
            tm0=toc;
            %% ʶ�����ж���ѵ����������ѵ�������ĳ�����
            idTrn=find(mask);
            [I,J] = ind2sub([row,col],idTrn);
            %trnLabel=labels(idTrn);
            trnLabel=predictedLabel(idTrn);
            A=X(:,idTrn);%ѵ������
            %������Ծ����ɳ������ڰ�������ѵ������
            % �򲻰���ѵ�������ĳ����صľ�ֵ��������
            id=find((SpInfo.ntp>1 | SpInfo.ntp==0)&SpInfo.unrecg);
            nT=numel(id);
            Y=zeros(dim,nT);
            yTypes=cell(nT,1);
            It=zeros(nT,1);
            Jt=zeros(nT,1);
            for t=1:nT
                idt=SpInfo.gIdx{id(t)};%
                Y(:,t)=mean(X(:,idt),2);%��t�������������ݼ��ľ�ֵ����
                yTypes{t}=SpInfo.types{id(t)};%��t���������������ѵ���������
                [r0,c0]=ind2sub([row,col],idt);%��t���������������
                It(t)=round(mean(r0));%��t��������������λ��������
                Jt(t)=round(mean(c0));%��t��������������λ��������
            end
            %%
            tstLabel=labels(idTst);
            %ratio��1-ratioΪ�׾��롢�ռ������ռ����;
            lambda=LmdSets(nameNb,pth);
            %���þ����Ȩ�ع��������������з��ࣻ
            %%%%%%%%%%%%%%%%ֱ�ӷ�%%%%%%%%%%%%%%%%%%%%%%%%%
            tic
            predLabel=DWLRC(A,Y,trnLabel,I,J,It,Jt,yTypes,lambda);
            for t=1:nT
                idt=SpInfo.gIdx{id(t)};%
                predictedLabel(idt)=predLabel(t);
            end
            tm1=toc+tm0;
            %% �������ʶ�𾫶�
            [OA1, AA1, K, IA1]=ClassifyAccuracy(tstLabel,predictedLabel(idTst));
            %[IA2,OA2,AA2]=ComputeAccuracy(predictedLabel(idTst),tstLabel,nClass,nListClass-nListTrn);
            disp([P expT lambda  OA1 AA1 K tm1])
            tmp=[P expT lambda [OA1 AA1 K IA1']*100 tm1];
            dlmwrite(fileName,tmp,'-append','delimiter','\t','precision','%.4f')
        end%end of for expT
    end%end of for P
end%end of for nameNb
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [OA, AA, K, IA]=ClassifyAccuracy(true_label,estim_label)
% function ClassifyAccuracy(true_label,estim_label)
% This function compute the confusion matrix and extract the OA, AA
% and the Kappa coefficient.
%http://kappa.chez-alice.fr/kappa_intro.htm

l=length(true_label);
nb_c=max(true_label);

%compute the confusion matrix
confu=zeros(nb_c);
for i=1:l
    confu(true_label(i),estim_label(i))= confu(true_label(i),estim_label(i))+1;
end

OA=trace(confu)/sum(confu(:)); %overall accuracy
IA=diag(confu)./sum(confu,2);  %class accuracy
IA(isnan(IA))=0;
number=size(IA,1);

AA=sum(IA)/number;
Po=OA;
Pe=(sum(confu)*sum(confu,2))/(sum(confu(:))^2);
K=(Po-Pe)/(1-Pe);%kappa coefficient
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function predictedLabel=DWLRC(A,Y,trnLabel,I,J,It,Jt,yTypes,lambda)
%�����Ȩ���Իع������
% min||Aix-y||_2^2+lambda||Wx||_2^2;
% Ai'Aix-A'y+lambdaW'Wx=0 =>x=(Ai'Ai+lambdaW'W)\(A'y)
% so Aix-y=Ai*inv(Ai'*Ai+lambda*W'*W)*Ai'y-y

nClass=max(trnLabel);
nTst=numel(It);
predictedLabel=zeros(nTst,1);
parfor t=1:nTst
    r0=It(t);
    c0=Jt(t);
    y=Y(:,t);
    err0=inf;
    if isempty(yTypes{t})
        classArray=1:nClass;
        nc=nClass;
    else
        classArray=yTypes{t};
        nc=numel(classArray);
    end
    for k=1:nc
        c=classArray(k);
        id=trnLabel==c;
        Ac=A(:,id);
        Ic=I(id);
        Jc=J(id);
        nck=numel(Ic);
        %%�����Ȩ����
        d=(Ic-r0).^2+(Jc-c0).^2;%�ռ����
        W=diag(lambda*d);
        %%
        x=(Ac'*Ac+W)\(Ac'*y);
        d=Ac*x-y;
        %err=d'*d/(x'*x);%% ����(||Acx-y||/||x||)^2
        err=d'*d;
        if err<err0
            err0=err;
            predictedLabel(t)=c;
        end
    end
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [labels_t,numlabels]=SuperpixelSegmentation(data,numSuperpixels)

[nl, ns, nb] = size(data);
x = data;
x = reshape(x, nl*ns, nb);
x = x';

input_img = zeros(1, nl * ns * nb);
startpos = 1;
for i = 1 : nl
    for j = 1 : ns
        input_img(startpos : startpos + nb - 1) = data(i, j, :);
        startpos = startpos + nb;
    end
end


%% perform Regional Clustering

%numSuperpixels = 200;  % number of segments
compactness = 0.1; % compactness2 = 1-compactness, compactness*dxy+compactness2*dspectral
dist_type = 2; % 1:ED��2��SAD; 3:SID; 4:SAD-SID
seg_all = 1; % 1: All pixels are clustered�� 2��exist un-clustered pixels
% labels:segment no of each pixel
% numlabels: actual number of segments
[labels, numlabels, ~, ~] = RCSPP(input_img, nl, ns, nb, numSuperpixels, compactness, dist_type, seg_all);
clear input_img;

labels_t = zeros(nl, ns, 'int32');
for i=1:nl
    for j=1:ns
        labels_t(i,j) = labels((i-1)*ns+j);
    end
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%