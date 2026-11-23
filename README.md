# Đồ án Khai thác dữ liệu và ứng dụng: Khai thác tập phổ biến bằng giải thuật FP-growth - Nhóm 7

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/cosude/Data-Mining-FIM-Group-7/blob/main/notebooks/demo.ipynb)

Đồ án tìm hiểu và cài đặt lại thuật toán **FP-growth** bằng ngôn ngữ Julia theo bài báo *Mining FrequentPatterns without Candidate Generation (Han et al., 2000)* cũng như áp dụng các kỹ thuật tối ưu bộ nhớ và thời gian cho **FP-growth**.

## 1. Demo Google Colab

Để chạy notebook demo của đồ án trên Google Colab, vui lòng truy cập vào link sau:

```bash
https://colab.research.google.com/github/cosude/Data-Mining-FIM-Group-7/blob/main/notebooks/demo.ipynb
```

## 2. Cấu trúc thư mục

```text
Data-Mining-FIM-Group-7/
├── src/                    # Mã nguồn cài đặt cơ bản và có tối ưu của FP-Growth
├── applications/           # Mã nguồn chương 3: Ứng dụng thực tế
├── experiments/            # Mã nguồn chương 2: Thực nghiệm
├── tests/                  # Kiểm thử tự động
├── notebooks/              # Demo notebook
├── docs/                   # Báo cáo
├── tools/                  # Thư viện SPMF - `spmf.jar`
├── data/                   # Dữ liệu thực nghiệm và kết quả
├── demo.jl                 # Mã nguồn CLI để chạy hai cài đặt FP-growth cho .txt
├── download_benchmark.jl   # Mã nguồn tải tự động 5 tập dữ liệu benchmark từ SPMF
├── download_app_data.jl    # Mã nguồn tải dữ liệu cho phần ứng dụng thực tế
└── Project.toml            # Các thư viện cần thiết của Julia

```

## 3. Cách cài đặt môi trường

### Yêu cầu

* **Julia** phiên bản $\ge 1.9$ (khuyến khích $1.11$ trở lên).
* **Git** (để clone mã nguồn).
* **Java (JRE/JDK)** để chạy đối chiếu trực tiếp với thư viện `spmf.jar`.

### Các bước cài đặt

**1. Clone repository và di chuyển vào thư mục chính:**
```bash
git clone [https://github.com/cosude/Data-Mining-FIM-Group-7.git](https://github.com/cosude/Data-Mining-FIM-Group-7.git)
cd Data-Mining-FIM-Group-7

```

**2. Cài đặt các package từ `Project.toml`:**
```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'

```

**3. Tải các tập dữ liệu benchmark:**
```bash
julia --project=. download_benchmark.jl

```
Dữ liệu sẽ được tự động tải về thư mục `data/benchmark/`.

**4. Tải các tập dữ liệu cho phần ứng dụng thực tế:**
```bash
julia --project=. download_app_data.jl

```
Dữ liệu cho ứng dụng 1 - phân tích giỏ hàng sẽ được lưu ở `data/market_basket/` và ứng 2 - phân tích dữ liệu sinh học lưu ở `data/splice/`.

## Dữ liệu sử dụng

### 1. Các tập dữ liệu Benchmark
Nguồn: [SPMF Open-Source Data Mining Library — Public Datasets](https://www.philippe-fournier-viger.com/spmf/index.php?link=datasets.php)

| Tập dữ liệu | Đặc điểm | Link tải |
| :--- | :--- | :--- |
| **Chess** | Dày đặc (3,196 giao dịch) | [chess.txt](https://www.philippe-fournier-viger.com/spmf/publicdatasets/chess.txt) |
| **Mushroom** | Dày đặc (8,416 giao dịch) | [mushroom.txt](https://www.philippe-fournier-viger.com/spmf/publicdatasets/mushroom.txt) |
| **Accidents** | Dày đặc (340,183 giao dịch) | [accidents.txt](https://www.philippe-fournier-viger.com/spmf/publicdatasets/accidents.txt) |
| **Retail** | Thưa (88,162 giao dịch) | [retail.txt](https://www.philippe-fournier-viger.com/spmf/publicdatasets/retail.txt) |
| **T10I4D100K** | Tổng hợp, thưa (100,000 giao dịch) | [T10I4D100K.txt](https://www.philippe-fournier-viger.com/spmf/publicdatasets/T10I4D100K.txt) |

### 2. Tập dữ liệu chương 3: Ứng dụng thực tế

| Ứng dụng | Tập dữ liệu | Link tải |
| :--- | :--- | :--- |
| **Ứng dụng 1 (Market Basket)** | Groceries Dataset | [groceries.csv](https://raw.githubusercontent.com/stedy/Machine-Learning-with-R-datasets/master/groceries.csv) |
| **Ứng dụng 2 (DNA Splice-junction)** | UCI Molecular Biology (Splice) | [splice.data](https://archive.ics.uci.edu/ml/machine-learning-databases/molecular-biology/splice-junction-gene-sequences/splice.data) |

### 4.2. Chạy kiểm thử tự động

```bash
julia --project=. tests/runtests.jl

```

### 4.3. Chạy chương 3: Ứng dụng thực tế

* **Ứng dụng 1 — Phân tích giỏ hàng (Market Basket Analysis):**
```bash
# Chạy với tham số mặc định (minsup = 0.01, minconf = 0.2, top = 10)
julia --project=. applications/app1_market_basket.jl

# Tùy chỉnh ngưỡng minsup, minconf và số luật hiển thị
julia --project=. applications/app1_market_basket.jl --minsup 0.005 --minconf 0.3 --top 15

```


Kết quả được lưu tại `data/results/app1_market_basket/association_rules.csv`.
* **Ứng dụng 2 — Khai thác mẫu chuỗi DNA (UCI Splice-junction):**
```bash
# Chạy với tham số mặc định (minsup = 0.4, top = 10)
julia --project=. applications/app2_splice.jl

# Tùy chỉnh ngưỡng minsup và số mẫu hiển thị
julia --project=. applications/app2_splice.jl --minsup 0.35 --top 15

```


Kết quả được lưu tại `data/results/app2_splice/`.

### 4.4. Chạy chương 2: thực nghiệm

```bash
julia --project=. experiments/exp1_correctness.jl
julia --project=. experiments/exp2_runtime_vs_minsup.jl
julia --project=. experiments/exp4_memory.jl
julia --project=. experiments/exp5_scalability.jl
julia --project=. experiments/exp6_avg_length.jl

```

Các tệp CSV kết quả sẽ được lưu vào các thư mục con tương ứng trong `data/results/`.