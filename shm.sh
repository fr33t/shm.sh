#!/bin/bash
help() {
    echo "$0"
    echo "$0 ls"
    echo "$0 add nickname user@example.com 22 password"
    echo "$0 rm nickname "
    echo "$0 cp nickname:/tmp/example.txt ."
    echo "$0 cp example.txt nickname:/tmp"
}
select_option() {
clear
echo -e "Enter $0 help for help\n"
  choices=("$@")   # 将选项数组声明为全局变量
  selected=0       # 初始化选择索引
  num_choices=${#choices[@]}

  tput civis        # 隐藏光标
  trap "tput cnorm; exit" EXIT  # 在脚本退出时恢复光标并退出

  # 记录当前光标位置
  tput sc           # 保存当前光标位置

  while true; do
    # 移动光标到记录的位置
    tput rc

    # 清除之前的内容
    for i in $(seq 0 $((num_choices - 1))); do
      tput el  # 清除到行尾
    done

    # 重新输出选项
    for index in "${!choices[@]}"; do
      if [ $index -eq $selected ]; then
        printf "\033[31m> ${choices[$index]}\033[0m\n"  # 高亮显示选中的选项
      else
        echo "  ${choices[$index]}"
      fi
    done

    read -n1 -s key  # 读取单个按键并保持输入的隐私

    case "$key" in
      A)  # 上箭头
        if [ $selected -gt 0 ]; then
          selected=$((selected - 1))
          tput cuu 1  # 光标上移1行
        fi
        ;;
      B)  # 下箭头
        if [ $selected -lt $(( num_choices - 1 )) ]; then
          selected=$((selected + 1))
          tput cud 1  # 光标下移1行
        fi
        ;;
      "")  # 回车键
        break
        ;;
    esac
  done

  tput cnorm  # 恢复光标

  # 打印最终结果日志
  selected_option="${choices[$selected]}"
}

# pre check util
commands=("xxd" "base64" "expect" "ssh" "scp")
for cmd in "${commands[@]}"; do
    if ! which "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd command is not available."
        exit 1
    fi
done

# init
mkdir -p $HOME/.config/
touch $HOME/.config/.shm

# read db
data=()
while IFS= read -r line; do
    data+=("$line")
done < "$HOME/.config/.shm"
length=${#data[@]}

# main
case "$#" in
    0)
    # list all
        if ["${#data[@]}" = 0]; then
            exit 3
        fi
        options=()
        for (( i=0; i<$length; i++ )); do
            read -r -a each <<< "${data[$i]}"
            line="$i"
            for (( j=0; j<${#each[@]}-1; j++));do
                line+=" ${each[$j]}"
            done
            options+=("$line")
        done
    
        select_option "${options[@]}"
        id=$(("${selected_option%% *}")) # get id
        for (( i=0; i<=id; i++)); do
            read -r -a each <<< "${data[$i]}"
            USER_HOST="${each[1]}"
            PORT="${each[2]}"
            PASSWORD="`echo ${each[3]} | base64 -d | xxd -r -p`"

            expect -c "
                set user_host \"$USER_HOST\"
                set port \"$PORT\"

                spawn ssh -p \$port \$user_host -o StrictHostKeyChecking=no
                expect {
                    \"password:\" {
                        send \"$PASSWORD\r\"
                    }
                    # 处理连接问题
                    \"Permission denied\" {
                        puts \"Permission denied. Please check your credentials.\"
                        exit 1
                    }
                    \"Could not resolve hostname\" {
                        puts \"Could not resolve hostname. Please check the host address.\"
                        exit 1
                    }
                }
                interact
                "
        done
        ;;
    1)
    # ssh list
        if [ "$1" = "help" ]; then
            help
            exit 0
        fi

        if [ "$1" != "ls" ]; then
            echo "Use correct operater"
            exit 2
        fi

        for (( i=0; i<$length; i++ )); do
            read -r -a each <<< "${data[$i]}"
            line="$i"
            for (( j=0; j<${#each[@]}-1; j++));do
                line+="\t${each[$j]}"
            done
            echo -e "$line"
        done
        ;;
    2)
    # delete target
        if [ "$1" != "rm" ]; then
            echo "Use correct operater"
            exit 2
        fi

        echo -n > $HOME/.config/.shm # clear the file
        for (( i=0; i<$length; i++ )); do
            read -r -a each <<< "${data[$i]}"
            if [ "$2" = "${each[0]}" ]; then
                continue
            fi
            echo "${data[$i]}" >> $HOME/.config/.shm
        done
        ;;
    3)
        echo "cp file to"
        ;;
    5)
    # add target
        # shm add xzmu bash@xzmu.freet.tech 22 123456
        if [ "$1" != "add" ]; then
            echo "Use correct operater"
            exit 2
        fi
        name="$2"
        user_host="$3"
        port="$4"
        password="$5"
        # check repeat
        for (( i=0; i<$length; i++ )); do
            read -r -a each <<< "${data[$i]}"
            if [ "$2" = "${each[0]}" ]; then
                echo "Name $2 has existed!"
                exit 3
            fi
        done
        passwd="`echo -n "$password" | xxd -p | base64`"
        res="$name $user_host $port $passwd"
        echo "$res" >> $HOME/.config/.shm
        ;;
    *)
        help
        exit 3
        ;;
esac
