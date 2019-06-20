#!/usr/bin/env bash

## Sistema para auxiliar o uso do git sem a necessidade de executar comandos
## Escrito por:     Rodrigo Henrique Oliveira
## E-mail:          sh@rhorigami.com
## Versão:          1.0
## Licença:         GPLv3
## Projeto:         https://github.com/rhorigami/ShellScript-Git-Commands

#######################################
############ Configurações ############
#######################################
FILE_OUTPUT="/tmp/rho_out"      #Arquivo para processamento
GIT_SERVIDOR="origin"           #Servidor para envio do git
BRANCH_PRODUCAO="master"        #Branch de produção
BRANCH_HOMOLOGACAO="homolog"    #Branch de homologação
BG_PRODUCAO="\Zb\Z1\Zr"         #Cor quando estiver em produção
BG_HOMOLOGACAO="\Zb\Z5\Zr"      #Cor quando estiver em homologação
BG_OUTROS="\Zn"                 #Cor para os outros branchs

##Verificar se Dialog esta instalado....
if ! which dialog > /dev/null; then
    echo -e "Dialog não encontrado, deseja instalar? (s/N) \c"
    read opcao
    if [ "$opcao" == "s" ]; then
        sudo apt-get update
        sudo apt-get -y install dialog
    else
        echo "Não foi possível abrir a aplicação."
        exit
    fi
fi
#### continue
OPCOES_DEFAULT="dialog --stdout --colors --clear --cancel-label \"Sair daqui\" --ok-label \"OK\" "
function dialogInfobox {
    dialog --colors --backtitle "$BACKTITLE" --backtitle "$BACKTITLE" --title "${1}" --infobox "${2}" 0 0
}
function dialogInputbox {
    minhaVar=$( dialog --stdout --colors --clear --cancel-label "Sair daqui" --ok-label "OK" --backtitle "$BACKTITLE" --title "${1}" --inputbox "${2}" 0 0 )
    minhaVar2=$?
    echo "$minhaVar"
    return $minhaVar2
}
function dialogYesNo {
    minhaVar=$( dialog --stdout --colors --clear --cancel-label "Não" --ok-label "Sim" --backtitle "$BACKTITLE" --title "${1}" --yesno "${2}" 0 0 )
    return $?
}
function commitar {
    OPCOES=$( dialogInputbox "${BG_BRANCH}Você está comitando em '${BRANCH_ATUAL^^}'\Zn" "Digite seu comentário:" )
    if [ $? -eq 1 -o "${OPCOES}" == "" ]; then
        dialogInfobox '\Z1\ZbErro.' 'Não foi possivel comitar.'
        sleep 2
    else
        dialogInfobox 'Commitando.' "Comentário ${OPCOES}"
        git add .
        git commit -am "${OPCOES}"
        sleep 1
    fi
}
function listandoBranch {
    git status -sb --ignored  | grep '^\([^!#]\)' > $FILE_OUTPUT &
    sleep 1
    DEU_ERRO=$( stat --printf="%s" $FILE_OUTPUT )
    if [ $DEU_ERRO -eq 0 ]; then
        listarBranchOpc
    else
        dialogYesNo "Atenção" "Existem arquivos não comitados.\nDeseja continuar mesmo assim?"
        if [ $? -eq 0 ]; then
            listarBranchOpc
        fi
    fi
}
function listarBranchOpc {
    unset listarBranch
    unset listarBranchOpt
    listarBranch=( ${listarBranch[@]} `git branch -l | tr '*' ' '` )
    a=1
    for((i=0;i<${#listarBranch[@]};i++)); do
        listarBranchOpt="${listarBranchOpt} ${i} '${listarBranch[$i]}'"
    done
    OPCOES=$( eval "${OPCOES_DEFAULT} --backtitle \"$BACKTITLE\" --title 'Deseja mudar para qual branch?' --menu 'Você está no branch \Zb${BRANCH_ATUAL^^}\Zn' 0 0 0 \
        ${listarBranchOpt[@]} \
    ")
    if [ $? -eq 0 ]; then
        BRANCH_SEL=${listarBranch[$OPCOES]}
        if [ $BRANCH_SEL != ${BRANCH_ATUAL} ]; then
            dialogInfobox '\Z1\ZbAtenção.' "Alterando para o branch \Zb${BRANCH_SEL^^}\Zn"
            git checkout $BRANCH_SEL
            BRANCH_ATUAL=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
            if [ $BRANCH_SEL != $BRANCH_ATUAL ]; then
                dialogInfobox '\Z1\ZbErro.' 'Não foi possivel alterar.'
                sleep 2
            fi
        fi
    fi
}
function listarStatus {
    dialogInfobox "Status." "Gerando listagem..."
    git status -sb --ignored > $FILE_OUTPUT &
    sleep 1
    $( eval "${OPCOES_DEFAULT} --backtitle \"$BACKTITLE\" --title 'Status.' --textbox $FILE_OUTPUT 0 0 ")
    rm $FILE_OUTPUT
}
function listarArquivos {
    dialogInfobox "Listando arquivos de ${BRANCH_ATUAL^^}." "Gerando listagem..."
    git ls-tree -r $BRANCH_ATUAL --name-only > $FILE_OUTPUT &
    sleep 1
    $( eval "${OPCOES_DEFAULT} --backtitle \"$BACKTITLE\" --title 'Listando arquivos de ${BRANCH_ATUAL^^}.' --textbox $FILE_OUTPUT 0 0 ")
    rm $FILE_OUTPUT
}
function enviarBranchAtual {
    dialogYesNo "Atenção" "Deseja enviar $BRANCH_ATUAL para o servidor $GIT_SERVIDOR"
    if [ $? -eq 0 ]; then
        git pull $GIT_SERVIDOR $BRANCH_ATUAL
        git status -sb --ignored  | grep '^\(UU\s\)' > $FILE_OUTPUT &
        sleep 1
        DEU_ERRO=$( stat --printf="%s" $FILE_OUTPUT )
        if [ $DEU_ERRO -eq 0 ]; then
            git push $GIT_SERVIDOR $BRANCH_ATUAL
        else
            dialogInfobox '\Z1\ZbErro.' "Não foi possivel enviar $BRANCH_ATUAL por favor verifique conflitos."
            sleep 3
        fi
    fi
}
function novoBranch {
    OPCOES=$( dialogInputbox "Nova funcionalidade." "Qual é o nome do novo branch?" )
    if [ $? -eq 0 ]; then
        dialogInfobox "Status." "Gerando novo branch \Zb${OPCOES// /_}\Zn"
        git checkout $BRANCH_PRODUCAO
        BRANCH_ATUAL=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
        if [ "$BRANCH_PRODUCAO" != "$BRANCH_ATUAL" ]; then
            dialogInfobox '\Z1\ZbErro.' "Não foi possivel alterar. $BRANCH_PRODUCAO -> $BRANCH_ATUAL"
            sleep 2
            return 1
        fi
        git pull $GIT_SERVIDOR $BRANCH_PRODUCAO
        git checkout -b ${OPCOES// /_}
    fi
}
function baixarProducaoBranchAtual {
    git checkout $BRANCH_PRODUCAO
    BRANCH_SEL=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
    if [ "$BRANCH_PRODUCAO" != "$BRANCH_SEL" ]; then
        dialogInfobox '\Z1\ZbErro.' "Não foi possivel acessar $BRANCH_PRODUCAO"
        sleep 2
        return 1
    fi
    git pull $GIT_SERVIDOR $BRANCH_PRODUCAO
    git checkout $BRANCH_ATUAL
    BRANCH_SEL=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
    if [ "$BRANCH_ATUAL" != "$BRANCH_SEL" ]; then
        dialogInfobox '\Z1\ZbErro.' "Não foi possivel acessar $BRANCH_ATUAL por favor verifique conflitos."
        sleep 2
        return 1
    fi
    git merge $BRANCH_PRODUCAO
}
function mergeBranch {
    if [ $# == 1 ]; then
        BRANCH_SEL=$1
        case $BRANCH_SEL in
            "${BRANCH_PRODUCAO}") BRANCH_NOME=${BG_PRODUCAO}"PRODUÇÃO" ;;
            "${BRANCH_HOMOLOGACAO}") BRANCH_NOME=${BG_HOMOLOGACAO}"HOMOLOGAÇÃO" ;;
            *) BG_BRANCH=${BG_OUTROS}${BRANCH_SEL} ;;
        esac
        if [ $BRANCH_SEL == $BRANCH_PRODUCAO -a $BRANCH_ATUAL == $BRANCH_HOMOLOGACAO ]; then
            dialogInfobox '\Z1\ZbErro.' "Você não pode fazer o merge do branch ${BG_HOMOLOGACAO}HOMOLOGAÇÃO\Zn com $BRANCH_NOME\Zn !Peça auxilio imediatamente!!!!!!!!"
            sleep 5
            return 1
        fi
        dialogYesNo "Atenção" "Deseja fazer o merge do branch ${BRANCH_ATUAL^^} com o ${BRANCH_NOME}\Zn"
        if [ $? -eq 0 ]; then
            git checkout $BRANCH_SEL
            BRANCH_A=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
            if [ "$BRANCH_A" != "$BRANCH_SEL" ]; then
                dialogInfobox '\Z1\ZbErro.' "Não foi possivel acessar $BRANCH_SEL por favor verifique conflitos."
                sleep 2
                return 1
            fi
            git pull origin $BRANCH_SEL
            git merge $BRANCH_ATUAL
            git status -sb --ignored  | grep '^\(UU\s\)' > $FILE_OUTPUT &
            DEU_ERRO=$( stat --printf="%s" $FILE_OUTPUT )
            if [ $DEU_ERRO -eq 0 ]; then
                git push $GIT_SERVIDOR $BRANCH_SEL --no-thin
                git checkout $BRANCH_ATUAL
            else
                dialogInfobox '\Z1\ZbErro.' "Não foi possivel enviar $BRANCH_SEL por favor verifique conflitos."
                sleep 3
            fi
        fi
    else
        dialogInfobox '\Z1\ZbErro.' "Não foi possivel acessar $BRANCH_PRODUCAO"
        sleep 2
        return 1
    fi
}
function limparBranchLocal {
    TOTALTXT=$(git branch --merged $GIT_SERVIDOR/$BRANCH_PRODUCAO|grep -v "\*\|${BRANCH_PRODUCAO}"|grep -v "\*\|${BRANCH_HOMOLOGACAO}")
    TOTAL=$(echo $TOTALTXT|xargs -n 1|wc -l)
    if [ "$TOTALTXT" != "" -a $TOTAL -gt 0 ]; then
        BRANCHS=$(echo $TOTALTXT|tr " " '\n' )
        dialogYesNo "Atenção" "Tem certeza que deseja excluir os branchs do git local?
${BRANCHS}"
        if [ $? -eq 0 ]; then
            dialogInfobox 'ATENÇÃO' "Removendo branchs
${BRANCHS}"
            echo $TOTALTXT| xargs -n 1 git branch -d
            sleep 2
        fi
    else
        dialogInfobox '\Z1\ZbErro.' "Não existem branchs para serem removidos."
        sleep 2
        return 1
    fi
}
function limparBranchRemoto {
    git fetch -p
    TOTALTXT=$( git branch -r --merged $GIT_SERVIDOR/$BRANCH_PRODUCAO | grep -v "^.*${BRANCH_PRODUCAO}" | sed s:$GIT_SERVIDOR/:: |xargs -n 1 echo )
    TOTAL=$(echo $TOTALTXT|xargs -n 1|wc -l)
    if [ "$TOTALTXT" != "" -a $TOTAL -gt 0 ]; then
        dialogYesNo "Atenção" "Tem certeza que deseja excluir os branchs do git remoto?
${TOTALTXT}"
        if [ $? -eq 0 ]; then
            dialogInfobox 'ATENÇÃO' "Removendo branchs
${TOTALTXT}"
            git branch -r --merged $GIT_SERVIDOR/$BRANCH_PRODUCAO | grep -v "^.*${BRANCH_PRODUCAO}" | sed s:$GIT_SERVIDOR/:: |xargs -n 1 git push origin --delete
        fi
    else
        dialogInfobox '\Z1\ZbErro.' "Não existem branchs para serem removidos."
        sleep 2
        return 1
    fi
}
function historico {
    git log $branch --name-status --pretty=format:"----------------------------------%n%aN %H | %cd %n        < %s > %x09" --no-merges
}
function removerArquivos {
    dialogYesNo "Atenção" "Tem certeza que deseja excluir os arquivos não comitados?"
    if [ $? -eq 0 ]; then
        git checkout -f
        git clean -df
    fi
}

while : ; do
    BRANCH_ATUAL=$(git branch | sed -n -e 's/^\* \(.*\)/\1/p')
    OPCOES_TELA01="01 'Comitar'
02 'Status.'
03 'Alterar de branch.'
04 'Nova funcionalidade.'
05 'Enviar dados de ${BRANCH_ATUAL^^} para o servidor.'
06 'Baixar dados de ${BG_PRODUCAO}PRODUÇÃO\Zn para ${BRANCH_ATUAL^^}.'
07 'Aplicar modificações de ${BRANCH_ATUAL^^} em ${BG_HOMOLOGACAO}HOMOLOGAÇÃO\Zn.'
08 'Aplicar modificações de ${BRANCH_ATUAL^^} em ${BG_PRODUCAO}PRODUÇÃO\Zn.'
09 'Limpar branchs locais com relação à ${BG_PRODUCAO}PRODUÇÃO\Zn.'
10 'Limpar branchs remotos com relação à ${BG_PRODUCAO}PRODUÇÃO\Zn.'
11 'Historico do branchs.'
12 'Listar arquivos do branchs.'
13 'Remover arquivos não comitados.'"
    case $BRANCH_ATUAL in
        "${BRANCH_PRODUCAO}") BG_BRANCH=$BG_PRODUCAO ;;
        "${BRANCH_HOMOLOGACAO}") BG_BRANCH=$BG_HOMOLOGACAO ;;
        *) BG_BRANCH=$BG_OUTROS ;;
    esac
    BACKTITLE="${BG_BRANCH}Você no branch ${BRANCH_ATUAL^^} \Zn"
    OPCOES=$( eval "${OPCOES_DEFAULT} --backtitle \"$BACKTITLE\" --title '${BG_BRANCH}Você esta no branch '${BRANCH_ATUAL^^}'\Zn' --menu \"O que deseja fazer?\" 0 0 0 "${OPCOES_TELA01[@]}" ")
    case $OPCOES in
        01) commitar ;;
        02) listarStatus ;;
        03) listandoBranch ;;
        04) novoBranch ;;
        05) enviarBranchAtual ;;
        06) baixarProducaoBranchAtual ;;
        07) mergeBranch $BRANCH_HOMOLOGACAO ;;
        08) mergeBranch $BRANCH_PRODUCAO ;;
        09) limparBranchLocal ;;
        10) limparBranchRemoto ;;
        11) historico ;;
        12) listarArquivos ;;
        13) removerArquivos ;;
        *) clear; exit;
    esac
done
