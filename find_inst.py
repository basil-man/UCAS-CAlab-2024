import re


def find_inst_prefix(filename):
    with open(filename, "r") as file:
        content = file.read()
    matches = re.findall(r"\binst_\w+", content)
    unique_matches = set(matches)
    return unique_matches


if __name__ == "__main__":
    filename = "IDreg.v"
    results = find_inst_prefix(filename)
    # 以 inst_1 | inst_2 | inst_3 ... 的形式输出
    if results:
        output = " | ".join(sorted(results))  # 使用 sorted() 以便按字母顺序输出
        print(output)
