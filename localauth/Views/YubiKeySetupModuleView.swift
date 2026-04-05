import SwiftUI

struct YubiKeySetupModuleView: View {
    let finishTitle: String
    let showsCancelHint: Bool
    let onFinish: () -> Void

    @State private var stage: Stage = .readiness
    @State private var hasDevicesNearby: Bool?
    @State private var hasConfiguredSlot2: Bool?
    @State private var stepIndex = 0

    init(
        finishTitle: String = String(localized: "开始使用"),
        showsCancelHint: Bool = true,
        onFinish: @escaping () -> Void
    ) {
        self.finishTitle = finishTitle
        self.showsCancelHint = showsCancelHint
        self.onFinish = onFinish
    }

    private enum Stage {
        case readiness
        case slotQuestion
        case stepByStep
    }

    private let setupSteps = [
        String(localized: "电脑上下载 YubiKey Manager"),
        String(localized: "1、点击 Application"),
        String(localized: "2、在展开列表中选择 OTP"),
        String(localized: "3、若有原有配置，先点击 Delete，再点击 Long Touch (Slot 2) 下的 Configure"),
        String(localized: "4、默认选中的是 Yubico OTP，请勾选 Challenge-response"),
        String(localized: "5、点击右侧 Generate 生成 Secret key，随后可拔出 YubiKey")
    ]

    var body: some View {
        VStack(spacing: 22) {
            if stage == .readiness {
                readinessContent
            } else if stage == .slotQuestion {
                slotQuestionContent
            } else {
                stepByStepContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(Color.black.ignoresSafeArea())
    }

    private var readinessContent: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "您的电脑和YubiKey是否都在您身边？"))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                optionCard(title: String(localized: "是"), selected: hasDevicesNearby == true) {
                    hasDevicesNearby = true
                }

                optionCard(title: String(localized: "否"), selected: hasDevicesNearby == false) {
                    hasDevicesNearby = false
                }
            }

            if hasDevicesNearby == false, showsCancelHint {
                Text(String(localized: "当您的YubiKey NFC版本与电脑都在身边时，可以到设置里点击“YubiKey配置教程”继续。"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.42))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 4)

            Button {
                if hasDevicesNearby == true {
                    stage = .slotQuestion
                } else if hasDevicesNearby == false {
                    onFinish()
                }
            } label: {
                Text(hasDevicesNearby == true ? String(localized: "继续") : finishTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan.opacity(hasDevicesNearby == nil ? 0.4 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(hasDevicesNearby == nil)
        }
    }

    private var slotQuestionContent: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "您的YubiKey是否配置过Long Touch (Slot 2)？"))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)

                Text(String(localized: "请先确认设备侧的 OTP 槽位配置。"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                optionCard(title: String(localized: "是"), selected: hasConfiguredSlot2 == true) {
                    hasConfiguredSlot2 = true
                }

                optionCard(title: String(localized: "否"), selected: hasConfiguredSlot2 == false) {
                    hasConfiguredSlot2 = false
                }
            }

            if hasConfiguredSlot2 == true {
                Text(String(localized: "已配置过，可直接开始使用。"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.green.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 4)

            Button {
                if hasConfiguredSlot2 == true {
                    onFinish()
                } else if hasConfiguredSlot2 == false {
                    stepIndex = 0
                    stage = .stepByStep
                }
            } label: {
                Text(hasConfiguredSlot2 == true ? finishTitle : String(localized: "继续"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan.opacity(hasConfiguredSlot2 == nil ? 0.4 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(hasConfiguredSlot2 == nil)
        }
    }

    private var stepByStepContent: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "YubiKey配置步骤"))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)

                Text("\(stepIndex + 1)/\(setupSteps.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(setupSteps[stepIndex])
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.76))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                Button {
                    if stepIndex == 0 {
                        stage = .slotQuestion
                    } else {
                        stepIndex -= 1
                    }
                } label: {
                    Text(String(localized: "上一步"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    if stepIndex == setupSteps.count - 1 {
                        onFinish()
                    } else {
                        stepIndex += 1
                    }
                } label: {
                    Text(stepIndex == setupSteps.count - 1 ? finishTitle : String(localized: "下一步"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private func optionCard(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selected ? .cyan : .white.opacity(0.45))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(selected ? 0.10 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Color.cyan : Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
