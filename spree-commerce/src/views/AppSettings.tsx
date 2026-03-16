import {
    Box,
    Button,
    Divider,
    Icon,
    SettingsView
} from "@stripe/ui-extension-sdk/ui";

const AppSettings = () => {
    return (
        <SettingsView>
            <Box
                css={{
                    padding: "large",
                    borderRadius: "medium",
                    width: "fit"
                }}
            >
                <Box
                    css={{
                        font: "heading",
                        stack: "x",
                        alignY: "center",
                        gap: "small",
                        marginBottom: "small",
                    }}
                >
                    <Icon name="sparkle" />
                    Spree Commerce
                </Box>
                <Box>
                    Install this app to generate a restricted API key for your Spree Commerce store.
                    Copy the key into your Spree Admin panel under Payments &gt; Stripe to complete setup.
                </Box>
                <Box
                    css={{
                        stack: "x",
                        gap: "small",
                        marginTop: "medium",
                    }}
                >
                    <Button type="primary" target="_blank" href="https://spreecommerce.org/docs/integrations/payments/stripe">
                        View setup instructions
                        <Icon name="external" />
                    </Button>
                    <Button target="_blank" href="https://spreecommerce.org">
                        Learn more
                        <Icon name="external" />
                    </Button>
                </Box>
            </Box>
            <Box css={{ marginTop: "large" }}>
                <Box css={{ font: "heading", marginBottom: "small" }}>
                    Permissions
                </Box>
                <Divider />
                <Box css={{ font: "body", marginTop: "medium" }}>
                    This app requests access to manage payments, customers, refunds,
                    and tax calculations on behalf of your Spree store.
                </Box>
            </Box>
        </SettingsView>
    );
};

export default AppSettings;
